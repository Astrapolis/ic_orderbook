from ic.canister import Canister
from ic.client import Client
from ic.identity import Identity
from ic.agent import Agent
from ic.candid import encode, decode, Types

init_icp = 10000
init_cycles = 10000000

class ICOrderbook:
    def __init__(self, name):
        iden = Identity()
        client = Client(url="http://127.0.0.1:8000")
        agent = Agent(iden, client)
        # read governance candid from file
        icorderbook_did = open("../.dfx/ic/canisters/ic_orderbook/ic_orderbook.did").read()
        # create a icorderbook canister instance
        self.name = name
        self.canister = Canister(agent=agent, canister_id="rrkah-fqaaa-aaaaa-aaaaq-cai", candid=icorderbook_did)

# call canister method with instance

icorderbook = ICOrderbook('test')
icorderbook.canister