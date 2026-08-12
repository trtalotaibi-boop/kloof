#!/usr/bin/env python3
import argparse
import json
import os
import sys
import urllib.parse
import urllib.request
from collections import Counter, defaultdict
from datetime import datetime, timedelta, timezone
from typing import Any

import firebase_admin
from firebase_admin import credentials, firestore

RIYADH_TZ = timezone(timedelta(hours=3))


def _required_env(name: str) -> str:
    value = os.getenv(name, "").strip()
    if not value:
        raise RuntimeError(f"Missing required environment variable: {name}")
    return value


def _init_firestore():
    raw = _required_env("FIREBASE_SERVICE_ACCOUNT_JSON")
    service_account = json.loads(raw)
    if not firebase_admin._apps:
        firebase_admin.initialize_app(credentials.Certificate(service_account))
    return firestore.client()


def _period_bounds(period: str, now: datetime) -> tuple[datetime, datetime, str]:
    now = now.astimezone(RIYADH_TZ)
    if period == "weekly":
        end = now
        start = end - timedelta(days=7)
        label = f"آخر 7 أيام ({start:%d/%m} - {end:%d/%m})"
        return start, end, label

    if period == "monthly":
        first_this_month = now.replace(day=1, hour=0, minute=0, second=0, microsecond=0)
        end = first_this_month
        previous_month_last_day = first_this_month - timedelta(days=1)
        start = previous_month_last_day.replace(day=1, hour=0, minute=0, second=0, microsecond=0)
        label = f"شهر {start:%m/%Y}"
        return start, end, label

    raise ValueError(f"Unsupported period: {period}")


def _as_datetime(value: Any) -> datetime | None:
    if value is None:
        return None
    if isinstance(value, datetime):
        dt = value
    elif hasattr(value, "to_datetime"):
        dt = value.to_datetime()
    else:
        return None
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    return dt.astimezone(RIYADH_TZ)


def _fetch_bookings(db, start: datetime, end: datetime) -> list[dict[str, Any]]:
    # createdAt is the safest field for measuring demand generated during the period.
    query = (
        db.collection("bookings")
        .where("createdAt", ">=", start.astimezone(timezone.utc))
        .where("createdAt", "<", end.astimezone(timezone.utc))
    )
    rows: list[dict[str, Any]] = []
    for doc in query.stream():
        data = doc.to_dict() or {}
        data["_id"] = doc.id
        rows.append(data)
    return rows


def _fetch_prior_pairs(db, before: datetime) -> set[tuple[str, str]]:
    """Return customer/barber pairs that existed before this reporting period."""
    pairs: set[tuple[str, str]] = set()
    query = db.collection("bookings").where("createdAt", "<", before.astimezone(timezone.utc))
    for doc in query.stream():
        data = doc.to_dict() or {}
        customer = str(data.get("customerId") or "").strip()
        barber = str(data.get("barberId") or "").strip()
        if customer and barber:
            pairs.add((customer, barber))
    return pairs


def _pct(numerator: int, denominator: int) -> float:
    if denominator <= 0:
        return 0.0
    return round((numerator / denominator) * 100, 1)


def _clamp(value: float, low: float = 0.0, high: float = 100.0) -> float:
    return max(low, min(high, value))


def _score(metrics: dict[str, Any], target_barbers: int) -> int:
    active_ratio = _pct(metrics["active_barbers"], max(target_barbers, 1))
    acceptance = metrics["acceptance_rate"]
    completion = metrics["completion_rate_of_accepted"]
    new_share = metrics["first_time_customer_share"]
    completed_per_barber = metrics["completed_per_active_barber"]

    # Targets mirror the 30-day validation scorecard, but are intentionally transparent.
    completed_productivity = _clamp((completed_per_barber / 5.0) * 100)
    score = (
        _clamp(active_ratio) * 0.20
        + _clamp(acceptance) * 0.20
        + _clamp(completion) * 0.25
        + _clamp(new_share) * 0.15
        + completed_productivity * 0.20
    )
    return round(score)


def _status_for_score(score: int) -> tuple[str, str]:
    if score >= 75:
        return "🟢", "استمر"
    if score >= 50:
        return "🟡", "عدّل"
    return "🔴", "راجع قبل التوسع"


def _build_metrics(bookings: list[dict[str, Any]], prior_pairs: set[tuple[str, str]]) -> dict[str, Any]:
    statuses = Counter(str(row.get("status") or "pending").lower() for row in bookings)
    total = len(bookings)
    rejected = statuses["rejected"]
    accepted = statuses["accepted"] + statuses["completed"]
    completed = statuses["completed"]
    pending = statuses["pending"]

    active_barbers = {str(row.get("barberId") or "").strip() for row in bookings}
    active_barbers.discard("")

    unique_customers = {str(row.get("customerId") or "").strip() for row in bookings}
    unique_customers.discard("")

    first_time = 0
    valid_pairs = 0
    seen_in_period: set[tuple[str, str]] = set()
    for row in sorted(bookings, key=lambda r: _as_datetime(r.get("createdAt")) or datetime.min.replace(tzinfo=RIYADH_TZ)):
        customer = str(row.get("customerId") or "").strip()
        barber = str(row.get("barberId") or "").strip()
        if not customer or not barber:
            continue
        pair = (customer, barber)
        if pair in seen_in_period:
            continue
        seen_in_period.add(pair)
        valid_pairs += 1
        if pair not in prior_pairs:
            first_time += 1

    per_barber_completed: dict[str, int] = defaultdict(int)
    for row in bookings:
        if str(row.get("status") or "pending").lower() == "completed":
            barber = str(row.get("barberId") or "").strip()
            if barber:
                per_barber_completed[barber] += 1

    completed_per_active = round(completed / len(active_barbers), 1) if active_barbers else 0.0

    return {
        "requests": total,
        "accepted": accepted,
        "rejected": rejected,
        "pending": pending,
        "completed": completed,
        "active_barbers": len(active_barbers),
        "unique_customers": len(unique_customers),
        "acceptance_rate": _pct(accepted, total),
        "completion_rate_of_accepted": _pct(completed, accepted),
        "first_time_customer_share": _pct(first_time, valid_pairs),
        "first_time_customer_pairs": first_time,
        "completed_per_active_barber": completed_per_active,
        "per_barber_completed": dict(per_barber_completed),
    }


def _format_report(period: str, label: str, metrics: dict[str, Any], score: int, target_barbers: int) -> str:
    icon, decision = _status_for_score(score)
    title = "التقرير الأسبوعي" if period == "weekly" else "التقرير الشهري"

    lines = [
        f"📊 KLOOF — {title}",
        f"🗓 {label}",
        "",
        f"الحلاقون النشطون: {metrics['active_barbers']}/{target_barbers}",
        f"طلبات الحجز: {metrics['requests']}",
        f"المقبولة: {metrics['accepted']} ({metrics['acceptance_rate']}%)",
        f"المرفوضة: {metrics['rejected']}",
        f"المعلقة: {metrics['pending']}",
        f"الحلاقات المكتملة: {metrics['completed']}",
        f"الإكمال من الطلبات المقبولة: {metrics['completion_rate_of_accepted']}%",
        f"عملاء/حلاق لأول مرة: {metrics['first_time_customer_pairs']} ({metrics['first_time_customer_share']}%)",
        f"متوسط الحلاقات المكتملة لكل حلاق نشط: {metrics['completed_per_active_barber']}",
        "",
        f"{icon} تقييم الإنتاجية: {score}/100",
        f"القرار: {decision}",
    ]

    if metrics["requests"] == 0:
        lines.extend(["", "⚠️ لا توجد طلبات خلال الفترة؛ لا يمكن اعتبار الدرجة دليلًا على أداء السوق."])

    if metrics["pending"] > 0:
        lines.append("⚠️ توجد حجوزات معلقة؛ راجعها لأنها تخفض وضوح القياس.")

    # Current booking documents do not contain price/revenue, so never invent revenue.
    lines.extend([
        "",
        "💰 الدخل الإضافي: غير محسوب حاليًا لأن سجل الحجز لا يحتوي قيمة الحلاقة.",
        "ملاحظة: التقرير يقيس السلوك الفعلي المسجل في KLOOF فقط.",
    ])
    return "\n".join(lines)


def _send_telegram(message: str) -> None:
    token = _required_env("TELEGRAM_BOT_TOKEN")
    chat_id = _required_env("TELEGRAM_CHAT_ID")
    url = f"https://api.telegram.org/bot{token}/sendMessage"
    payload = urllib.parse.urlencode({
        "chat_id": chat_id,
        "text": message,
        "disable_web_page_preview": "true",
    }).encode("utf-8")
    req = urllib.request.Request(url, data=payload, method="POST")
    with urllib.request.urlopen(req, timeout=20) as response:
        body = response.read().decode("utf-8")
        if response.status != 200:
            raise RuntimeError(f"Telegram API error {response.status}: {body}")


def main() -> int:
    parser = argparse.ArgumentParser(description="Send KLOOF productivity report to Telegram")
    parser.add_argument("--period", choices=["weekly", "monthly"], required=True)
    parser.add_argument("--dry-run", action="store_true", help="Print report without sending Telegram")
    args = parser.parse_args()

    target_barbers = int(os.getenv("KLOOF_TARGET_BARBERS", "5"))
    now = datetime.now(RIYADH_TZ)
    start, end, label = _period_bounds(args.period, now)

    db = _init_firestore()
    bookings = _fetch_bookings(db, start, end)
    prior_pairs = _fetch_prior_pairs(db, start)
    metrics = _build_metrics(bookings, prior_pairs)
    score = _score(metrics, target_barbers)
    report = _format_report(args.period, label, metrics, score, target_barbers)

    print(report)
    if not args.dry_run:
        _send_telegram(report)
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as exc:
        print(f"REPORT_FAILED: {exc}", file=sys.stderr)
        sys.exit(1)
