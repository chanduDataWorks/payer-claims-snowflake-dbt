"""
Generate synthetic healthcare payer data (members, providers, claims) as dbt seeds.

All data is fake and randomly generated - no real PHI is used anywhere.
The claims file deliberately includes "dirty" records (mixed-case statuses,
extra whitespace, resubmitted duplicates) so the staging layer has real
cleaning work to do, just like production payer feeds.

Usage:
    python scripts/generate_data.py            # writes CSVs into ./seeds
"""

import csv
import random
from datetime import date, datetime, timedelta
from pathlib import Path

random.seed(42)

SEEDS_DIR = Path(__file__).resolve().parent.parent / "seeds"
SEEDS_DIR.mkdir(exist_ok=True)

N_MEMBERS = 600
N_PROVIDERS = 60
N_CLAIMS = 6000

FIRST_NAMES = ["James", "Mary", "Robert", "Patricia", "John", "Jennifer", "Michael", "Linda",
               "David", "Elizabeth", "William", "Barbara", "Richard", "Susan", "Joseph", "Jessica",
               "Thomas", "Sarah", "Carlos", "Maria", "Daniel", "Nancy", "Kevin", "Lisa", "Anh", "Wei"]
LAST_NAMES = ["Smith", "Johnson", "Williams", "Brown", "Jones", "Garcia", "Miller", "Davis",
              "Rodriguez", "Martinez", "Hernandez", "Lopez", "Wilson", "Anderson", "Thomas",
              "Taylor", "Moore", "Jackson", "Martin", "Lee", "Nguyen", "Chen", "Patel", "Kim"]
COUNTIES = ["Los Angeles", "Orange", "San Bernardino", "Riverside", "San Diego", "Ventura"]
PLANS = ["HMO_GOLD", "HMO_SILVER", "PPO_GOLD", "PPO_SILVER", "MEDICARE_ADV"]

SPECIALTIES = [("Family Medicine", "PCP"), ("Internal Medicine", "PCP"), ("Pediatrics", "PCP"),
               ("Cardiology", "SPECIALIST"), ("Orthopedics", "SPECIALIST"),
               ("Dermatology", "SPECIALIST"), ("Neurology", "SPECIALIST"),
               ("General Hospital", "FACILITY"), ("Urgent Care", "FACILITY"),
               ("Retail Pharmacy", "PHARMACY")]
CITIES = ["Long Beach", "Anaheim", "Irvine", "Pasadena", "Riverside", "San Diego", "Ontario"]

DX_CODES = ["E11.9", "I10", "J06.9", "M54.5", "Z00.00", "F41.1", "E78.5", "K21.9", "J45.909", "R51.9"]
PROCEDURES = {
    "PROF": [("99213", 150), ("99214", 220), ("99203", 180), ("93000", 90), ("20610", 260)],
    "INST": [("0450", 1800), ("0120", 4200), ("0360", 9500), ("0300", 350)],
    "RX":   [("NDC-00093", 45), ("NDC-00378", 120), ("NDC-59762", 380)],
}
DENIAL_REASONS = ["NOT_COVERED", "PRIOR_AUTH_MISSING", "DUPLICATE", "OUT_OF_NETWORK", "TIMELY_FILING"]


def rand_date(start: date, end: date) -> date:
    return start + timedelta(days=random.randint(0, (end - start).days))


def write_csv(name: str, header: list, rows: list) -> None:
    path = SEEDS_DIR / f"{name}.csv"
    with path.open("w", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(header)
        writer.writerows(rows)
    print(f"wrote {len(rows):>5} rows -> {path.relative_to(SEEDS_DIR.parent)}")


# ---------------------------------------------------------------- members
members = []
for i in range(1, N_MEMBERS + 1):
    plan = random.choice(PLANS)
    if plan == "MEDICARE_ADV":
        dob = rand_date(date(1940, 1, 1), date(1959, 12, 31))
    else:
        dob = rand_date(date(1955, 1, 1), date(2022, 12, 31))
    cov_start = rand_date(date(2023, 1, 1), date(2025, 6, 1)).replace(day=1)
    # ~20% of members have termed coverage
    cov_end = ""
    if random.random() < 0.2:
        cov_end = (rand_date(cov_start + timedelta(days=90), date(2025, 12, 31))
                   .replace(day=28)).isoformat()
    members.append([
        f"M{i:06d}",
        random.choice(FIRST_NAMES),
        random.choice(LAST_NAMES),
        dob.isoformat(),
        random.choice(["M", "F"]),
        plan,
        random.choice(COUNTIES),
        cov_start.isoformat(),
        cov_end,
        datetime(2025, 12, 31, 23, 0, 0).isoformat(sep=" "),
    ])
write_csv("raw_members",
          ["member_id", "first_name", "last_name", "date_of_birth", "gender", "plan_code",
           "county", "coverage_start_date", "coverage_end_date", "updated_at"],
          members)

# -------------------------------------------------------------- providers
providers = []
for i in range(N_PROVIDERS):
    specialty, ptype = random.choice(SPECIALTIES)
    npi = str(1_000_000_000 + random.randint(0, 899_999_999))
    name = (f"Dr. {random.choice(FIRST_NAMES)} {random.choice(LAST_NAMES)}"
            if ptype in ("PCP", "SPECIALIST")
            else f"{random.choice(CITIES)} {specialty}")
    providers.append([npi, name, specialty, ptype, random.choice(CITIES), "CA",
                      "IN" if random.random() < 0.85 else "OUT"])
write_csv("raw_providers",
          ["provider_npi", "provider_name", "specialty", "provider_type", "city", "state",
           "network_status"],
          providers)

# ----------------------------------------------------------------- claims
claims = []
member_lookup = {m[0]: m for m in members}
for i in range(1, N_CLAIMS + 1):
    member = random.choice(members)
    provider = random.choice(providers)
    ptype = provider[3]
    claim_type = "RX" if ptype == "PHARMACY" else ("INST" if ptype == "FACILITY" else "PROF")
    proc, base_price = random.choice(PROCEDURES[claim_type])

    cov_start = date.fromisoformat(member[7])
    cov_end = date.fromisoformat(member[8]) if member[8] else date(2025, 12, 31)
    service_date = rand_date(max(cov_start, date(2024, 1, 1)), cov_end) if cov_end > max(cov_start, date(2024, 1, 1)) else cov_start
    received_date = service_date + timedelta(days=random.randint(1, 45))

    billed = round(base_price * random.uniform(0.8, 1.6), 2)
    allowed = round(billed * random.uniform(0.45, 0.85), 2)

    r = random.random()
    if r < 0.12:
        status, denial = "DENIED", random.choice(DENIAL_REASONS)
    elif r < 0.17:
        status, denial = "PENDING", ""
    else:
        status, denial = "PAID", ""

    paid = round(allowed * random.uniform(0.7, 1.0), 2) if status == "PAID" else 0.0
    paid_date = (received_date + timedelta(days=random.randint(5, 30))).isoformat() if status == "PAID" else ""
    loaded_at = datetime.combine(received_date + timedelta(days=1), datetime.min.time())

    # inject dirty data the staging layer must clean
    status_raw = status
    if random.random() < 0.08:
        status_raw = f" {status.lower()} "
    claim_id = f"C{i:07d}"

    row = [claim_id, member[0], provider[0], claim_type, proc, random.choice(DX_CODES),
           service_date.isoformat(), received_date.isoformat(), paid_date,
           f"{billed:.2f}", f"{allowed:.2f}", f"{paid:.2f}", status_raw, denial,
           loaded_at.isoformat(sep=" ")]
    claims.append(row)

    # ~4% of claims get resubmitted (same claim_id, later load, corrected status)
    if random.random() < 0.04:
        resub = row.copy()
        resub[12] = "PAID"
        resub[13] = ""
        resub[11] = f"{round(allowed * 0.9, 2):.2f}"
        resub[8] = (received_date + timedelta(days=40)).isoformat()
        resub[14] = (loaded_at + timedelta(days=35)).isoformat(sep=" ")
        claims.append(resub)

random.shuffle(claims)
write_csv("raw_claims",
          ["claim_id", "member_id", "provider_npi", "claim_type", "procedure_code",
           "primary_dx_code", "service_date", "received_date", "paid_date", "billed_amount",
           "allowed_amount", "paid_amount", "claim_status", "denial_reason", "loaded_at"],
          claims)
