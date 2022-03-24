# ic_orderbook


```bash
cd ic_orderbook/
dfx help
dfx config --help
```

## Running the project locally

If you want to test your project locally, you can use the following commands:

```bash
# Starts the replica, running in the background
dfx start --background

# Deploys your canisters to the replica and generates your candid interface
dfx deploy
```

Once the job completes, your application will be available at `http://localhost:8000?canisterId={asset_canister_id}`.

Additionally, if you are making frontend changes, you can start a development server with

```bash
npm start
```

Which will start a server at `http://localhost:8080`, proxying API requests to the replica at port 8000.

update calls
```
deposit(receiver: Text, token: Text, value : Nat)
limit_order(side: Side, size: Nat, price: Nat, trader: Text)
cancel_order(order_id_remove : Nat)
check_balance(user: Text, token: Text)
```
query calls
```
check_balance(user: Text, token: Text) : async ?(Text, Text, Nat)
render_orders() : async [ImmutableOrder]
get_orders_by_trader(trader : Text) : async [ImmutableOrder]
```

local candid : http://r7inp-6aaaa-aaaaa-aaabq-cai.localhost:8000/
ic candid : https://a4gq6-oaaaa-aaaab-qaa4q-cai.raw.ic0.app/?id=ujiy7-mqaaa-aaaal-qatba-cai
