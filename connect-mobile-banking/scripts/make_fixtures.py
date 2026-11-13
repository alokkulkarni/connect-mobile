"""
make_fixtures.py
================
The mobile apps' Sample mode data: the banking app's own replies for the sample customer (CUST-001), made by its own
code, in memory. Nothing touches AWS. Run it again after the banking app's data or reply shapes change, then copy
fixtures/ into each app (see the README).

    python3 connect-mobile-banking/scripts/make_fixtures.py connect-mobile-banking/fixtures
"""
import json, os, sys, time
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
APP = ROOT / "connect-banking-app"
sys.path[:0] = [str(APP), str(APP / "api"), str(ROOT / "connect-money-hub"), str(ROOT / "connect-money-hub" / "api"),
                str(ROOT / "connect-card-dispute" / "lambda")]
os.environ["FLOW_VIEW"] = "off"
import banking_api, money_api
from moneyhub.service import MoneyHub
from moneyhub.store import MemoryStore
import dispute_model
from bankapp import disputes
from dispute_service import DisputeService
from dispute_store import MemoryStore as DisputeMemory

money_api.hub = MoneyHub(MemoryStore(time.time), time.time, page_url="https://app.example")
disputes._service = DisputeService(DisputeMemory(time.time), time.time, page_url="https://disputes.example")
payment = next(t for t in dispute_model.card_transactions("CUST-001") if "ELECTROWORLD" in t["merchant"])
disputes._service.start_card_dispute("CUST-001", payment["transaction_id"], "merchant")
token = money_api.hub.mint_link("CUST-001", "2").split("#k=")[1]
money_api.hub.save_goal("CUST-001", "Holiday in Japan", 3000, "2027-06-30", 800)

def call(route, **body):
    event = {"requestContext": {"http": {"method": "POST"}}, "rawPath": f"/api/{route}",
             "body": json.dumps({"token": token, **body})}
    reply = banking_api.lambda_handler(event, None)
    assert reply["statusCode"] == 200, (route, reply["body"][:300])
    return json.loads(reply["body"])

out = Path(sys.argv[1]); out.mkdir(parents=True, exist_ok=True)
fixtures = {
    "app_home": call("app/home"),
    "app_accounts_current": call("app/accounts", account="current"),
    "app_accounts_savings": call("app/accounts", account="savings"),
    "app_cards": call("app/cards"),
    "hub": call("hub"),
    "transactions_p1": call("transactions", page=1),
    "transactions_p2": call("transactions", page=2),
    "transactions_p3": call("transactions", page=3),
    "disputes": call("disputes"),
    "mortgage_config": {"products": __import__("bankapp.products", fromlist=["PRODUCTS"]).PRODUCTS},
}
fixtures["hub"].pop("logos", None)
for name, value in fixtures.items():
    (out / f"{name}.json").write_text(json.dumps(value, indent=1) + "\n")
    print(name, len(json.dumps(value)))
