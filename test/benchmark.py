from unicodedata import name
from ic.canister import Canister
from ic.client import Client
from ic.identity import Identity
from ic.agent import Agent
from ic.candid import encode, decode, Types
import random
import threading
import time

init_icp = 10000
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
        self.canister.mint('icp', 1000000)
        self.canister.mint('cycles', 100000000)
        self.canister.deposit(name, 'icp', 1000000)
        self.canister.deposit(name, 'cycles', 100000000)
# call canister method with instance

    def buy(self, size, price):
        return self.canister.buy(size, price, self.name)

    def sell(self, size, price):
        return self.canister.sell(size, price, self.name)


benchmark = []
def test(user_name, range_var):
    test_user = ICOrderbook(user_name)
    prices = list(range(1000, 1000+range_var))
    sizes = list(range(1000,1000+range_var))
    random.shuffle(prices)
    random.shuffle(sizes)

    for i in range(range_var):
        buy_order = test_user.buy(sizes[i], prices[i])
        print(buy_order)
        benchmark.append((buy_order, time.time()))
        sell_order = test_user.sell(sizes[i], prices[i])
        print(sell_order)
        benchmark.append((sell_order, time.time()))
    return (range_var)

if __name__ == "__main__":
    threads = []
    test_users = 200
    test_operations = 100
    for i in range(test_users):
        t = threading.Thread(target=test, args = ('test'+str(i), test_operations))
        threads.append(t)
        t.start()

    for t in threads:
        t.join()

    import csv

    with open("out.csv", "w", newline="") as f:
        writer = csv.writer(f)
        writer.writerows(benchmark)