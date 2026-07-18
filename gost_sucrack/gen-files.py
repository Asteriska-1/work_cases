#!/usr/bin/env python3
from __future__ import annotations

import argparse
import csv
import json
import random
from datetime import date, datetime, timedelta
from pathlib import Path
from faker import Faker

DEFAULT_SEED = 8
EXPECTED_FILE_COUNT = 150

CUSTOMER_COUNT = 35
TICKET_COUNT = 20
CONTRACT_COUNT = 18
INVOICE_FILE_COUNT = 10
UPLOAD_FILE_COUNT = 15
DB_BACKUP_COUNT = 8
FINANCE_FILE_COUNT = 8
HR_FILE_COUNT = 6

DEPARTMENTS = ["Support", "Sales", "Finance", "Operations", "IT", "Security"]
TICKET_PRIORITIES = ["low", "normal", "normal", "high", "urgent"]
TICKET_STATUSES = ["open", "pending", "resolved", "closed"]
CUSTOMER_STATUSES = ["active", "active", "active", "on_hold", "trial"]


def ensure_dir(path: Path) -> None:
    path.mkdir(parents=True, exist_ok=True)


def write_text(path: Path, content: str) -> Path:
    ensure_dir(path.parent)
    path.write_text(content, encoding="utf-8")
    return path


def write_json(path: Path, data: object) -> Path:
    ensure_dir(path.parent)
    path.write_text(json.dumps(data, indent=2), encoding="utf-8")
    return path


def write_csv(path: Path, header: list[str], rows: list[list[object]]) -> Path:
    ensure_dir(path.parent)

    with path.open("w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(header)
        writer.writerows(rows)

    return path


def random_date_iso(start: str, end: str) -> str:
    start_date = date.fromisoformat(start)
    end_date = date.fromisoformat(end)
    delta_days = (end_date - start_date).days

    return (start_date + timedelta(days=random.randint(0, delta_days))).isoformat()


def random_timestamp(day: str) -> str:
    d = date.fromisoformat(day)

    ts = datetime(
        d.year,
        d.month,
        d.day,
        random.randint(0, 23),
        random.randint(0, 59),
        random.randint(0, 59),
    )

    return ts.isoformat() + "Z"


def make_customers(fake: Faker) -> list[dict[str, object]]:
    customers = []

    for idx in range(1, CUSTOMER_COUNT + 1):
        customers.append({
            "customer_id": f"CUST-{idx:05d}",
            "company": fake.company(),
            "contact_name": fake.name(),
            "contact_email": fake.company_email(),
            "phone": fake.phone_number(),
            "billing_address": fake.address().replace("\n", ", "),
            "status": random.choice(CUSTOMER_STATUSES),
            "account_manager": fake.name(),
            "created_at": random_date_iso("2022-01-01", "2025-12-31"),
            "last_activity_at": random_date_iso("2026-05-01", "2026-07-12"),
        })

    return customers


def make_users(fake: Faker) -> list[dict[str, object]]:
    users = []

    for idx in range(1, 16):
        users.append({
            "user_id": f"USR-{idx:04d}",
            "name": fake.name(),
            "email": fake.email(),
            "department": random.choice(DEPARTMENTS),
            "role": random.choice(["agent", "agent", "manager", "billing", "admin_readonly"]),
            "enabled": random.choice([True, True, True, False]),
        })

    return users


def make_tickets(
    fake: Faker,
    customers: list[dict[str, object]],
    users: list[dict[str, object]],
) -> list[dict[str, object]]:
    subjects = [
        "Cannot access customer portal",
        "Invoice amount mismatch",
        "Contract renewal question",
        "Export job failed",
        "Password reset request",
        "Missing attachment in case history",
        "SLA breach notification",
        "API integration returns error",
        "Change billing contact",
        "Report download is incomplete",
    ]

    tickets = []

    for idx in range(1, TICKET_COUNT + 1):
        customer = random.choice(customers)
        assignee = random.choice(users)

        tickets.append({
            "ticket_id": f"TCK-{idx:06d}",
            "customer_id": customer["customer_id"],
            "company": customer["company"],
            "subject": random.choice(subjects),
            "priority": random.choice(TICKET_PRIORITIES),
            "status": random.choice(TICKET_STATUSES),
            "assignee": assignee["email"],
            "created_at": random_date_iso("2026-06-01", "2026-07-12"),
            "updated_at": random_date_iso("2026-07-01", "2026-07-12"),
            "last_comment": fake.paragraph(nb_sentences=random.randint(2, 5)),
        })

    return tickets


def generate_app_config(root: Path, fake: Faker) -> list[Path]:
    config_dir = root / "app" / "config"

    return [
        write_text(config_dir / "application.yml", f"""app:
  name: internal-crm
  environment: production
  public_url: https://crm.internal.local
  workers: {random.randint(4, 12)}
  log_level: info

features:
  customer_portal: true
  invoice_export: true
  audit_log: true
  ticket_queue: true
"""),
        write_text(config_dir / "database.yml", f"""production:
  adapter: postgresql
  host: 10.10.{random.randint(1, 20)}.{random.randint(10, 250)}
  port: 5432
  database: crm_prod
  username: crm_app
  pool: {random.randint(10, 30)}
  timeout: 5000
"""),
        write_text(config_dir / "storage.yml", """local:
  uploads_path: /srv/internal-crm/uploads
  exports_path: /srv/internal-crm/exports
  backup_path: /srv/internal-crm/backups
  max_upload_size_mb: 50
"""),
        write_json(config_dir / "integrations.json", {
            "mail": {
                "provider": "smtp",
                "host": "mail.internal.local",
                "port": 587,
                "from": "crm-notify@example.local",
            },
            "sso": {
                "enabled": True,
                "issuer": "https://sso.internal.local",
                "client_id": f"crm-{fake.uuid4()}",
            },
            "backup": {
                "enabled": True,
                "schedule": "0 2 * * *",
                "retention_days": 14,
            },
        }),
        write_text(config_dir / "workers.yml", """queues:
  default: 4
  exports: 2
  mailers: 2
  reports: 1

retry:
  max_attempts: 5
  backoff_seconds: 60
"""),
    ]


def generate_logs(root: Path, fake: Faker) -> list[Path]:
    logs_dir = root / "app" / "logs"
    created = []

    levels = ["INFO", "INFO", "INFO", "WARN", "ERROR"]
    actions = [
        "customer.profile.opened",
        "invoice.export.created",
        "ticket.status.changed",
        "contract.document.uploaded",
        "auth.login.success",
        "auth.login.failed",
        "backup.job.finished",
        "report.downloaded",
        "worker.job.started",
        "worker.job.finished",
    ]

    for day in range(1, 8):
        current_day = f"2026-07-{day:02d}"
        lines = []

        for _ in range(random.randint(120, 220)):
            lines.append(
                f"{random_timestamp(current_day)} {random.choice(levels)} "
                f"request_id={fake.uuid4()} "
                f"user={fake.user_name()} "
                f"src_ip={fake.ipv4_private()} "
                f"action={random.choice(actions)} "
                f"status={random.choice([200, 200, 200, 201, 204, 400, 403, 500])}"
            )

        created.append(
            write_text(
                logs_dir / f"production-2026-07-{day:02d}.log",
                "\n".join(lines) + "\n",
            )
        )

    for day in range(1, 5):
        current_day = f"2026-07-{day:02d}"
        lines = []

        for _ in range(random.randint(80, 140)):
            lines.append(
                f"{random_timestamp(current_day)} {random.choice(levels)} "
                f"job_id={fake.uuid4()} "
                f"queue={random.choice(['default', 'exports', 'mailers', 'reports'])} "
                f"duration_ms={random.randint(20, 20000)} "
                f"result={random.choice(['success', 'success', 'success', 'retry', 'failed'])}"
            )

        created.append(
            write_text(
                logs_dir / f"worker-2026-07-{day:02d}.log",
                "\n".join(lines) + "\n",
            )
        )

    for day in range(1, 4):
        current_day = f"2026-07-{day:02d}"
        lines = []

        for _ in range(random.randint(50, 100)):
            lines.append(
                f"{random_timestamp(current_day)} audit "
                f"actor={fake.user_name()} "
                f"ip={fake.ipv4_private()} "
                f"event={random.choice(['role.changed', 'user.disabled', 'invoice.approved', 'export.downloaded', 'contract.updated'])}"
            )

        created.append(
            write_text(
                logs_dir / f"audit-2026-07-{day:02d}.log",
                "\n".join(lines) + "\n",
            )
        )

    return created


def generate_exports(
    root: Path,
    customers: list[dict[str, object]],
    users: list[dict[str, object]],
    tickets: list[dict[str, object]],
) -> list[Path]:
    exports_dir = root / "app" / "exports"
    created = []

    created.append(write_csv(
        exports_dir / "customers-active-2026-07.csv",
        ["customer_id", "company", "contact_name", "contact_email", "status", "account_manager"],
        [
            [
                c["customer_id"],
                c["company"],
                c["contact_name"],
                c["contact_email"],
                c["status"],
                c["account_manager"],
            ]
            for c in customers
        ],
    ))

    created.append(write_csv(
        exports_dir / "users-2026-07.csv",
        ["user_id", "name", "email", "department", "role", "enabled"],
        [
            [
                u["user_id"],
                u["name"],
                u["email"],
                u["department"],
                u["role"],
                u["enabled"],
            ]
            for u in users
        ],
    ))

    created.append(write_csv(
        exports_dir / "support-tickets-2026-07.csv",
        ["ticket_id", "customer_id", "subject", "priority", "status", "assignee", "updated_at"],
        [
            [
                t["ticket_id"],
                t["customer_id"],
                t["subject"],
                t["priority"],
                t["status"],
                t["assignee"],
                t["updated_at"],
            ]
            for t in tickets
        ],
    ))

    created.append(write_csv(
        exports_dir / "invoices-open-2026-07.csv",
        ["invoice_id", "customer_id", "amount_eur", "status", "issued_at", "due_at"],
        [
            [
                f"INV-202607-{idx:04d}",
                random.choice(customers)["customer_id"],
                random.randint(500, 50000),
                random.choice(["issued", "overdue"]),
                "2026-07-01",
                "2026-07-28",
            ]
            for idx in range(1, 31)
        ],
    ))

    created.append(write_csv(
        exports_dir / "contracts-renewal-2026-q3.csv",
        ["contract_id", "customer_id", "renewal_date", "owner", "estimated_value_eur"],
        [
            [
                f"CTR-{idx:04d}",
                random.choice(customers)["customer_id"],
                random_date_iso("2026-07-01", "2026-09-30"),
                random.choice(users)["email"],
                random.randint(5000, 120000),
            ]
            for idx in range(1, 26)
        ],
    ))

    created.append(write_json(exports_dir / "sla-report-2026-07.json", {
        "period": "2026-07",
        "generated_at": "2026-07-12T23:30:00Z",
        "tickets_total": len(tickets),
        "sla_met_percent": random.randint(91, 99),
        "urgent_tickets": sum(1 for t in tickets if t["priority"] == "urgent"),
    }))

    created.append(write_json(exports_dir / "monthly-revenue-summary.json", {
        "period": "2026-07",
        "currency": "EUR",
        "total_customers": len(customers),
        "new_contracts": random.randint(5, 20),
        "renewals": random.randint(10, 30),
        "revenue": random.randint(350000, 900000),
    }))

    created.append(write_json(exports_dir / "data-quality-report.json", {
        "generated_at": "2026-07-12T22:00:00Z",
        "customers_checked": len(customers),
        "duplicate_emails": random.randint(0, 3),
        "missing_billing_address": random.randint(0, 4),
        "orphaned_tickets": random.randint(0, 2),
    }))

    return created


def generate_customer_files(root: Path, customers: list[dict[str, object]]) -> list[Path]:
    customer_dir = root / "data" / "customers"

    return [
        write_json(customer_dir / f"{c['customer_id'].lower()}.json", c)
        for c in customers
    ]


def generate_ticket_files(root: Path, tickets: list[dict[str, object]]) -> list[Path]:
    ticket_dir = root / "data" / "tickets"

    return [
        write_json(ticket_dir / f"{t['ticket_id'].lower()}.json", t)
        for t in tickets
    ]


def generate_contracts(
    root: Path,
    fake: Faker,
    customers: list[dict[str, object]],
) -> list[Path]:
    contracts_dir = root / "data" / "contracts"
    created = []

    for idx, customer in enumerate(random.sample(customers, CONTRACT_COUNT), start=1):
        content = f"""# Service Agreement

Contract ID: CTR-{idx:04d}
Customer: {customer['company']}
Primary contact: {customer['contact_name']} <{customer['contact_email']}>
Effective date: {random_date_iso('2024-01-01', '2026-05-31')}
Renewal date: {random_date_iso('2026-07-01', '2027-06-30')}

## Scope

{fake.paragraph(nb_sentences=6)}

## Service Level

{fake.paragraph(nb_sentences=5)}

## Billing Terms

Monthly service fee: EUR {random.randint(3000, 30000)}
Payment period: {random.choice([15, 30, 45])} days

## Notes

{fake.paragraph(nb_sentences=8)}
"""

        created.append(
            write_text(
                contracts_dir / f"contract-{idx:04d}-{customer['customer_id'].lower()}.md",
                content,
            )
        )

    return created


def generate_invoices(root: Path, customers: list[dict[str, object]]) -> list[Path]:
    invoices_dir = root / "data" / "invoices"
    created = []

    for idx in range(1, INVOICE_FILE_COUNT + 1):
        month = random.choice(["2026-03", "2026-04", "2026-05", "2026-06", "2026-07"])
        rows = []

        for line in range(1, random.randint(12, 28)):
            customer = random.choice(customers)

            rows.append([
                f"INV-{month.replace('-', '')}-{idx:02d}{line:03d}",
                customer["customer_id"],
                customer["company"],
                random.randint(500, 50000),
                random.choice(["paid", "paid", "issued", "overdue"]),
                f"{month}-{random.randint(1, 20):02d}",
                f"{month}-{random.randint(21, 28):02d}",
            ])

        created.append(write_csv(
            invoices_dir / f"invoices-batch-{idx:03d}.csv",
            ["invoice_id", "customer_id", "company", "amount_eur", "status", "issued_at", "due_at"],
            rows,
        ))

    return created


def generate_uploads(
    root: Path,
    fake: Faker,
    customers: list[dict[str, object]],
    tickets: list[dict[str, object]],
) -> list[Path]:
    uploads_dir = root / "uploads" / "support"
    created = []

    for idx in range(1, UPLOAD_FILE_COUNT + 1):
        customer = random.choice(customers)
        ticket = random.choice(tickets)

        if idx % 3 == 0:
            name = f"ticket-{ticket['ticket_id'].lower()}-error-report-{idx:03d}.txt"
            content = f"""Ticket: {ticket['ticket_id']}
Customer: {customer['company']}
Reported by: {customer['contact_email']}
Hostname: {fake.hostname()}
Source IP: {fake.ipv4_private()}

Error summary:
{fake.paragraph(nb_sentences=5)}

Observed behavior:
{fake.paragraph(nb_sentences=6)}
"""
        elif idx % 3 == 1:
            name = f"ticket-{ticket['ticket_id'].lower()}-request-notes-{idx:03d}.md"
            content = f"""# Request Notes

Ticket: {ticket['ticket_id']}
Customer: {customer['company']}
Priority: {ticket['priority']}

## Description

{fake.paragraph(nb_sentences=7)}

## Internal notes

{fake.paragraph(nb_sentences=5)}
"""
        else:
            name = f"ticket-{ticket['ticket_id'].lower()}-environment-{idx:03d}.json"
            content = json.dumps({
                "ticket_id": ticket["ticket_id"],
                "customer_id": customer["customer_id"],
                "hostname": fake.hostname(),
                "ip": fake.ipv4_private(),
                "browser": random.choice(["Chrome", "Firefox", "Edge"]),
                "os": random.choice(["Windows 11", "Ubuntu 22.04", "macOS 14"]),
                "submitted_at": random_timestamp("2026-07-12"),
            }, indent=2)

        created.append(write_text(uploads_dir / name, content))

    return created


def generate_db_backups(
    root: Path,
    customers: list[dict[str, object]],
    tickets: list[dict[str, object]],
) -> list[Path]:
    db_dir = root / "backups" / "db"
    created = []

    for idx in range(1, DB_BACKUP_COUNT + 1):
        day = f"2026-07-{idx:02d}"

        lines = [
            "-- PostgreSQL database dump",
            "-- Database: crm_prod",
            "CREATE TABLE customers (customer_id TEXT, company TEXT, contact_email TEXT, status TEXT);",
            "CREATE TABLE tickets (ticket_id TEXT, customer_id TEXT, priority TEXT, status TEXT);",
        ]

        for customer in customers:
            company = str(customer["company"]).replace("'", "")
            email = str(customer["contact_email"]).replace("'", "")

            lines.append(
                f"INSERT INTO customers VALUES ('{customer['customer_id']}', '{company}', '{email}', '{customer['status']}');"
            )

        for ticket in tickets:
            lines.append(
                f"INSERT INTO tickets VALUES ('{ticket['ticket_id']}', '{ticket['customer_id']}', '{ticket['priority']}', '{ticket['status']}');"
            )

        created.append(
            write_text(
                db_dir / f"crm_prod_{day}.sql",
                "\n".join(lines) + "\n",
            )
        )

    return created


def generate_backup_manifests(
    root: Path,
    fake: Faker,
    customers: list[dict[str, object]],
) -> list[Path]:
    manifests_dir = root / "backups" / "uploads"
    created = []

    for idx, day in enumerate(["2026-07-01", "2026-07-04", "2026-07-08"], start=1):
        objects = []

        for item in range(1, 26):
            objects.append({
                "filename": f"support-upload-{idx:02d}-{item:04d}.dat",
                "owner": random.choice(customers)["customer_id"],
                "size_bytes": random.randint(120000, 5000000),
                "sha256": fake.sha256(),
            })

        created.append(write_json(manifests_dir / f"upload-manifest-{day}.json", {
            "generated_at": f"{day}T02:15:00Z",
            "storage": "/srv/internal-crm/uploads",
            "objects": objects,
        }))

    return created


def generate_finance_files(root: Path, fake: Faker) -> list[Path]:
    finance_dir = root / "shared" / "finance"
    created = []

    for idx in range(1, FINANCE_FILE_COUNT + 1):
        rows = []

        for line in range(1, random.randint(15, 35)):
            rows.append([
                f"PAY-{idx:02d}{line:04d}",
                fake.company(),
                f"PO-{random.randint(10000, 99999)}",
                random.randint(500, 75000),
                random.choice(["approved", "approved", "pending", "rejected"]),
                random_date_iso("2026-07-01", "2026-09-30"),
            ])

        created.append(write_csv(
            finance_dir / f"supplier-payments-q3-batch-{idx:02d}.csv",
            ["payment_id", "supplier", "purchase_order", "amount_eur", "status", "planned_date"],
            rows,
        ))

    return created


def generate_hr_files(root: Path, fake: Faker) -> list[Path]:
    hr_dir = root / "shared" / "hr"
    created = []

    for idx in range(1, HR_FILE_COUNT + 1):
        rows = []

        for line in range(1, random.randint(10, 25)):
            rows.append([
                f"EXT-{idx:02d}{line:04d}",
                fake.name(),
                fake.email(),
                random.choice(DEPARTMENTS),
                random_date_iso("2024-01-01", "2026-07-12"),
                fake.name(),
            ])

        created.append(write_csv(
            hr_dir / f"contractors-list-{idx:02d}.csv",
            ["contractor_id", "name", "email", "department", "start_date", "manager"],
            rows,
        ))

    return created


def main() -> None:
    parser = argparse.ArgumentParser(description="Generate realistic Case 8 CRM server files.")
    parser.add_argument("target_dir", help="Directory where files will be created.")
    parser.add_argument("--seed", type=int, default=DEFAULT_SEED, help="Random seed.")
    parser.add_argument("--locale", default="en_US", help="Faker locale.")

    args = parser.parse_args()

    random.seed(args.seed)
    Faker.seed(args.seed)

    fake = Faker(args.locale)

    target_dir = Path(args.target_dir).expanduser().resolve()
    target_dir.mkdir(parents=True, exist_ok=True)

    customers = make_customers(fake)
    users = make_users(fake)
    tickets = make_tickets(fake, customers, users)

    created_files: list[Path] = []

    created_files += generate_app_config(target_dir, fake)
    created_files += generate_logs(target_dir, fake)
    created_files += generate_exports(target_dir, customers, users, tickets)
    created_files += generate_customer_files(target_dir, customers)
    created_files += generate_ticket_files(target_dir, tickets)
    created_files += generate_contracts(target_dir, fake, customers)
    created_files += generate_invoices(target_dir, customers)
    created_files += generate_uploads(target_dir, fake, customers, tickets)
    created_files += generate_db_backups(target_dir, customers, tickets)
    created_files += generate_backup_manifests(target_dir, fake, customers)
    created_files += generate_finance_files(target_dir, fake)
    created_files += generate_hr_files(target_dir, fake)

    if len(created_files) != EXPECTED_FILE_COUNT:
        raise RuntimeError(f"Expected {EXPECTED_FILE_COUNT} files, created {len(created_files)}")

    total_size = sum(path.stat().st_size for path in created_files)

    print(f"Created files: {len(created_files)}")
    print(f"Target directory: {target_dir}")
    print(f"Total size: {total_size} bytes ({total_size / 1024 / 1024:.2f} MiB)")


if __name__ == "__main__":
    main()
