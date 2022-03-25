from ic.canister import Canister
from ic.client import Client
from ic.identity import Identity
from ic.agent import Agent
from ic.candid import Types

iden = Identity()
client = Client()
agent = Agent(iden, client)
# read governance candid from file
governance_did = open("governance.did").read()
# create a governance canister instance
governance = Canister(agent=agent, canister_id="rrkah-fqaaa-aaaaa-aaaaq-cai", candid=governance_did)
# call canister method with instance
res = governance.list_proposals(
    {
        'include_reward_status': [],
        'before_proposal': [],
        'limit': 100,
        'exclude_topic': [],
        'include_status': [1]
    }
)