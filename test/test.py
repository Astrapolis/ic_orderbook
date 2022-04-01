from unicodedata import name
from ic.canister import Canister
from ic.client import Client
from ic.identity import Identity
from ic.agent import Agent
from ic.candid import encode, decode, Types
import random
import threading
import time

init_icp = 100
init_cycles = 10000000

class ICOrderbook:
    def __init__(self, name):
        iden = Identity()
        client = Client(url="http://127.0.0.1:8000")
        agent = Agent(iden, client)
        # read governance candid from file
        icorderbook_did = open("../src/declarations/ic_orderbook/ic_orderbook.did").read()
        # create a icorderbook canister instance
        self.name = name
        self.canister = Canister(agent=agent, canister_id="rrkah-fqaaa-aaaaa-aaaaq-cai", candid=icorderbook_did)
        self.canister.mint('icp', init_icp)
        self.canister.mint('cycles', init_cycles)
        self.canister.deposit(name, 'icp', init_icp)
        self.canister.deposit(name, 'cycles', init_cycles)
# call canister method with instance

    def buy(self, size, price):
        return self.canister.buy(size, price, self.name)

    def sell(self, size, price):
        return self.canister.sell(size, price, self.name)

# init test users
testuser1 = ICOrderbook('test1')
testuser2 = ICOrderbook('test2')

# 
testuser1.buy(10, 10)
assert()


