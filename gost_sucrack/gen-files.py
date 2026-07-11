#!/usr/bin/env python3
import argparse
import csv
import json
import random
from pathlib import Path
from faker import Faker
from xml.sax.saxutils import escape

DEFAULT_SEED = 8

SUBDIRS = [
    "Documents",
    "Finance",
    "HR",
    "Projects",
    "Backups",
    "Configs",
    "Logs",
    "Database",
]

FILE_PLAN = [
    ("Documents", "report", ".txt", 20, "text"),
    ("Documents", "meeting-notes", ".md", 15, "text"),
    ("Finance", "payroll", ".csv", 15, "csv"),
    ("Finance", "quarterly-report", ".json", 10, "json"),
    ("HR", "employees", ".csv", 10, "csv"),
    ("Projects", "project-plan", ".md", 15, "text"),
    ("Backups", "customer-dump", ".sql", 10, "sql"),
    ("Configs", "service", ".conf", 10, "conf"),
    ("Logs", "application", ".log", 10, "log"),
    ("Database", "assets", ".xml", 5, "xml"),
]


def write_text_file(path: Path, fake: Faker) -> None:
    paragraphs = [
        fake.paragraph(nb_sentences=random.randint(4, 10))
        for _ in range(random.randint(8, 18))
    ]
    path.write_text("\n\n".join(paragraphs) + "\n", encoding="utf-8")


def write_csv_file(path: Path, fake: Faker) -> None:
    rows = random.randint(40, 120)

    with path.open("w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(["employee_id", "name", "department", "email", "salary", "updated_at"])

        for i in range(rows):
            writer.writerow([
                10000 + i,
                fake.name(),
                random.choice(["IT", "Finance", "HR", "Legal", "Operations", "Security"]),
                fake.email(),
                random.randint(45000, 180000),
                fake.date_this_year().isoformat(),
            ])


def write_json_file(path: Path, fake: Faker) -> None:
    data = {
        "project": fake.bs(),
        "owner": fake.name(),
        "created_at": fake.iso8601(),
        "hosts": [
            {
                "hostname": f"srv-{random.randint(1, 200):03d}",
                "ip": fake.ipv4_private(),
                "role": random.choice(["web", "db", "backup", "monitoring", "worker"]),
                "enabled": random.choice([True, False]),
                "owner": fake.name(),
            }
            for _ in range(random.randint(20, 60))
        ],
    }

    path.write_text(json.dumps(data, indent=2), encoding="utf-8")


def write_log_file(path: Path, fake: Faker) -> None:
    levels = ["INFO", "WARN", "ERROR", "DEBUG"]
    services = ["auth", "billing", "inventory", "backup", "gateway", "scheduler"]

    lines = []
    for _ in range(random.randint(250, 700)):
        lines.append(
            f"{fake.date_time_this_year().isoformat()} "
            f"{random.choice(levels)} "
            f"{fake.ipv4_private()} "
            f"{random.choice(services)} "
            f"{fake.sentence(nb_words=random.randint(6, 14))}"
        )

    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def write_conf_file(path: Path, fake: Faker) -> None:
    content = f"""# Generated service configuration
service_name={fake.slug()}
listen_address={fake.ipv4_private()}
listen_port={random.randint(1024, 65000)}
workers={random.randint(2, 16)}
log_level={random.choice(["debug", "info", "warning", "error"])}
backup_enabled={random.choice(["true", "false"])}
backup_path=/srv/backups/{fake.slug()}
api_token={fake.sha256()[:32]}
"""
    path.write_text(content, encoding="utf-8")


def write_sql_file(path: Path, fake: Faker) -> None:
    lines = [
        "CREATE TABLE customers (id INTEGER PRIMARY KEY, name TEXT, email TEXT, city TEXT, balance INTEGER);"
    ]

    for i in range(random.randint(80, 180)):
        name = fake.name().replace("'", "")
        email = fake.email()
        city = fake.city().replace("'", "")
        balance = random.randint(0, 500000)

        lines.append(
            f"INSERT INTO customers VALUES ({i + 1}, '{name}', '{email}', '{city}', {balance});"
        )

    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def write_xml_file(path: Path, fake: Faker) -> None:
    items = []

    for _ in range(random.randint(30, 80)):
        items.append(
            f"  <asset>"
            f"<name>{escape(fake.hostname())}</name>"
            f"<ip>{escape(fake.ipv4_private())}</ip>"
            f"<owner>{escape(fake.name())}</owner>"
            f"<department>{escape(random.choice(['IT', 'Finance', 'HR', 'Legal', 'Operations']))}</department>"
            f"</asset>"
        )

    path.write_text("<assets>\n" + "\n".join(items) + "\n</assets>\n", encoding="utf-8")


WRITERS = {
    "text": write_text_file,
    "csv": write_csv_file,
    "json": write_json_file,
    "log": write_log_file,
    "conf": write_conf_file,
    "sql": write_sql_file,
    "xml": write_xml_file,
}


def main() -> None:
    parser = argparse.ArgumentParser(description="Generate realistic Case 8 training files.")
    parser.add_argument("target_dir", help="Directory where files will be created.")
    parser.add_argument("--seed", type=int, default=DEFAULT_SEED, help="Random seed.")
    parser.add_argument("--locale", default="en_US", help="Faker locale.")

    args = parser.parse_args()

    random.seed(args.seed)
    Faker.seed(args.seed)

    fake = Faker(args.locale)

    target_dir = Path(args.target_dir).expanduser().resolve()
    target_dir.mkdir(parents=True, exist_ok=True)

    created_files = []

    for subdir in SUBDIRS:
        (target_dir / subdir).mkdir(parents=True, exist_ok=True)

    for subdir, prefix, suffix, count, writer_name in FILE_PLAN:
        writer = WRITERS[writer_name]
        directory = target_dir / subdir

        for idx in range(1, count + 1):
            path = directory / f"{prefix}-{idx:03d}{suffix}"
            writer(path, fake)
            created_files.append(path)

    total_size = sum(path.stat().st_size for path in created_files)

    print(f"Created files: {len(created_files)}")
    print(f"Target directory: {target_dir}")
    print(f"Total size: {total_size} bytes ({total_size / 1024 / 1024:.2f} MiB)")


if __name__ == "__main__":
    main()
