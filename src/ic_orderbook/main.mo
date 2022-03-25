import Deque "mo:base/Deque";
import Array "mo:base/Array";
import Buffer "mo:base/Buffer";
import TrieMap "mo:base/TrieMap";
import Text "mo:base/Text";
import List "mo:base/List";
import Iter "mo:base/Iter";

actor {

  let book = TrieMap.TrieMap<Text, TrieMap.TrieMap<Text, Nat>>(Text.equal, Text.hash);
  let mint_account = "0000";
  let mint_bal = 1000000;  

  public func deposit(receiver: Text, token: Text, value : Nat) : async ?(Text, Text, Nat){
    let success = transfer_from_to(token, mint_account, receiver, value);
    switch success {
      case true {
        switch (check_token_balance(receiver, token)){
          case (null) null;
          case (?bal){
            ?(receiver, token, bal);
          }
        };
      };
      case false {
        null;
      }
    }
  };

  public query func check_balance(user: Text, token: Text) : async ?(Text, Text, Nat){
    switch (check_token_balance(user, token)){
      case (null) null;
      case (?bal){
        ?(user, token, bal);
      }
    };    
  };

  public func mint(token: Text, value : Nat) : async (Text, Text, Nat){
    switch (book.get(mint_account)) {
      case (null) {
        let token_bal = TrieMap.TrieMap<Text, Nat>(Text.equal, Text.hash);
        token_bal.put(token, value);
        book.put(mint_account, token_bal);
        (mint_account, token, value);
      };
      case (? token_bal) {
        switch (token_bal.get(token)) {
          case (null) {
            token_bal.put(token, value);
            (mint_account, token, value);
          };
          case (? old_balance) {
            token_bal.put(token, old_balance + value);
            (mint_account, token, old_balance + value);
          };
        };
      };
    };    
  };

  func transfer_from_to (token: Text, sender: Text, receiver: Text, value : Nat) : Bool {
    switch (book.get(sender)) {
      case (null) {
        return false;
      };
      case (? token_bal) {
        switch (token_bal.get(token)) {
          case (null) {
            return false;
          };
          case (? old_balance) {
            token_bal.put(token, old_balance - value);
          };
        };
      };
    };

    switch (book.get(receiver)) {
      case (null) {
        let token_bal = TrieMap.TrieMap<Text, Nat>(Text.equal, Text.hash);
        token_bal.put(token, value);
        book.put(receiver, token_bal);
      };
      case (? token_bal) {
        switch (token_bal.get(token)) {
          case (null) {
            token_bal.put(token, value);
          };
          case (? old_balance) {
            token_bal.put(token, old_balance + value);
          };
        };
      };
    };
    true;
  };

  func check_token_balance (user : Text, token : Text) : ?Nat {
    switch (book.get(user)) {
      case (null) {
        return null;
      };
      case (? bal) {
        bal.get(token);
      };
    };
  };


  type Side = { #buy; #sell;};
  type Pair = {#base; #quote};
  let pair = ("icp", "cycles");

  type Order = {
    side: Side;    
    size: Nat;
    price: Nat;
    trader: Text;
    order_id: Nat;
    var size_left : Nat;
  };

  type ImmutableOrder = {
    side: Side;    
    size: Nat;
    price: Nat;
    trader: Text;
    order_id: Nat;
    size_left : Nat;
  };


  type Receipt = {
    buy_order_id: Nat;    
    sell_order_id: Nat;
    size: Nat;
  };

  type UserHistory = {
      var order_ids : List.List<Nat>;
      var receipt_ids : List.List<Nat>;
  };
  
  type order_result = { #insufficient_fund; #success};

  let orders = Buffer.Buffer<Order>(10000);
  let receipts = Buffer.Buffer<Receipt>(10000);
  let user_history = TrieMap.TrieMap<Text, UserHistory>(Text.equal, Text.hash);
  var current_order_id = 0;
  let max_price = 1000000;
  let price_points : [var Deque.Deque<Nat>]= Array.init(max_price, Deque.empty<Nat>()); 
  var bid_max = 0;
  var ask_min = max_price + 1;

  func check_balance_in_book(trader : Text, token : Pair) : ?(Pair, Nat) {
    var balance_in_book = 0;
    switch token {
      case (#base){
        switch (user_history.get(trader)) {
          case null {return null;};
          case (?his) {
            for (id in (Iter.fromList(his.order_ids))){
              let order = orders.get(id);
              if (order.side == #sell){              
                balance_in_book += order.size_left;}
            }
          }
        }
      };
      case (#quote) {
        switch (user_history.get(trader)) {
          case null {return null;};
          case (?his) {
            for (id in (Iter.fromList(his.order_ids))){
              let order = orders.get(id);
              if (order.side == #buy) {
                balance_in_book += (order.size_left * order.price);
              }
            }
          }
        }      
      }
    };
    ?(token, balance_in_book);
  };

  func check_available_balance (trader : Text, token : Pair) : ?(Pair, Nat) {
    var balance_in_token = 0;
    var balance_in_book = 0;
    switch token {
      case (#base){
        switch (check_token_balance(trader, pair.0)){
          case (null) {};
          case (?bal) {balance_in_token := bal}
        }
      };
      case (#quote) {
        switch (check_token_balance(trader, pair.1)){
          case (null) {};
          case (?bal) {balance_in_token := bal}
        }        
      }
    };
    switch (check_balance_in_book(trader, token)) {
      case (null) {};
      case (?bal) {balance_in_book := bal.1};
    };
    ?(token, balance_in_token - balance_in_book);
  };

  func insert_order(side: Side, size: Nat, price: Nat, trader: Text) : Bool {
    switch side {
      case (#buy) {
        switch (check_available_balance(trader, #quote)) {
          case (null) {
            return false;
          };
          case (?(pair, bal)) {
            if (bal < size * price) {return false};
          }
        }
      };
      case (#sell) {
        switch (check_available_balance(trader, #base)) {
          case (null) {
            return false;
          };
          case (?(pair, bal)) {
            if (bal < size) {return false};
          }
        }
      };
    };
    let order : Order = {side = side; size = size; price = price; trader = trader ; order_id = current_order_id ; var size_left = size};
    orders.add(order);
    switch (user_history.get(trader)) {
      case (null) {
        user_history.put(trader, {var order_ids = List.make<Nat>(current_order_id); var receipt_ids : List.List<Nat> = List.nil()});
      };
      case (?h) {
        h.order_ids := List.push(current_order_id, h.order_ids);
      }
    };
    return true;
  };

  func remove_order(order_id_to_cancel : Nat) : Order {
    let order = orders.get(order_id_to_cancel);
    let (l, r) = price_points[order.price];
    var new_l : List.List<Nat> = List.nil();
    var new_r : List.List<Nat> = List.nil();
    for (order_id in Iter.fromList(l)) {
      if (order_id != order_id_to_cancel) {
        new_l := List.push(order_id, new_l);
      }
    };
    for (order_id in Iter.fromList(r)) {
      if (order_id != order_id_to_cancel) {
        new_r := List.push(order_id, new_r);
      }
    };
    price_points[order.price] := (new_l, new_r);

    let canceled_order = {side = order.side; size : Nat = order.size - order.size_left; price = order.price; trader = order.trader ; order_id = order.order_id ;  var size_left = 0};
    orders.put(order_id_to_cancel, canceled_order);
    canceled_order;
  };

  func matching_hook(buyer_order : Order, seller_order : Order, size : Nat) : Bool{
    var success = false;
    receipts.add({ buy_order_id = buyer_order.order_id; sell_order_id = seller_order.order_id; size = size;});
    success := transfer_from_to(pair.1, buyer_order.trader, seller_order.trader, size*seller_order.price);
    success := transfer_from_to(pair.0, seller_order.trader, buyer_order.trader, size);
    success;
  };


  func matching(new_order_id : Nat) : Order {
    var new_order = orders.get(new_order_id);
    switch (new_order.side) {
      case (#buy) {
        while ( new_order.price >= ask_min ) {
          var entries = price_points[ask_min];
          while ( Deque.isEmpty(entries) == false ) {
            switch (Deque.peekFront(entries)){
              case (null) {};
              case (?(deque_order_id)) {
                let order = orders.get(deque_order_id);
                if (order.size_left < new_order.size_left) {
                  let sucucess = matching_hook(new_order, order, order.size_left);
                  new_order.size_left -= order.size_left;
                  order.size_left := 0;
                  switch (Deque.popFront(entries)){
                    case (null) {};
                    case (?(poped_order_id, new_entries)) {
                      entries := new_entries;
                    }
                  }
                } else {
                  let sucucess = matching_hook(new_order, order, new_order.size_left);
                  if (order.size_left > new_order.size_left) {
                    order.size_left -= new_order.size_left;
                    new_order.size_left := 0;
                  } else {
                    switch (Deque.popFront(entries)){
                      case (null) {};
                      case (?(poped_order_id, new_entries)) {
                        new_order.size_left := 0;
                        order.size_left := 0;
                        entries := new_entries;
                      }
                    }                    
                  };                
                  return new_order;
                }
              }
            }
          };
          ask_min += 1;
        };
        price_points[new_order.price] := Deque.pushBack(price_points[new_order.price], new_order_id);
        if (bid_max < new_order.price) {
          bid_max := new_order.price;
        };
        return new_order;
      };
      case (#sell) {
        while ( new_order.price <= bid_max ) {
          var entries = price_points[bid_max];
          while ( Deque.isEmpty(entries) == false ) {
            switch (Deque.peekFront(entries)){
              case (null) {};
              case (?(deque_order_id)) {
                let order = orders.get(deque_order_id);
                if (order.size_left < new_order.size_left) {
                  let sucucess = matching_hook(order, new_order, order.size_left);
                  new_order.size_left -= order.size_left;
                  order.size_left := 0;
                  switch (Deque.popFront(entries)){
                    case (null) {};
                    case (?(poped_order_id, new_entries)) {
                      entries := new_entries;
                    }
                  }
                } else {
                  let sucucess = matching_hook(order, new_order, new_order.size_left);
                  if (order.size_left > new_order.size_left) {
                    order.size_left -= new_order.size_left;
                    new_order.size_left := 0;
                  } else {
                    switch (Deque.popFront(entries)){
                      case (null) {};
                      case (?(poped_order_id, new_entries)) {
                        new_order.size_left := 0;
                        order.size_left := 0;
                        entries := new_entries;
                      }
                    }                    
                  };                
                  return new_order;
                }
              }
            }
          };
          bid_max -= 1;
        };
        price_points[new_order.price] := Deque.pushBack(price_points[new_order.price], new_order_id);
        if (ask_min > new_order.price) {
          ask_min := new_order.price;
        };
        return new_order;
      };
    };
  };

  func order_to_immutable(order : Order) : ImmutableOrder {
    ({side = order.side; size = order.size; price = order.price; 
    trader = order.trader ; order_id = order.order_id ; size_left = order.size_left});
  };

  public func check_available_fund(trader : Text, token : Pair) : async ?(Pair, Nat){
      check_available_balance(trader, token);
  };

  public func limit_order(side: Side, size: Nat, price: Nat, trader: Text) : async ?ImmutableOrder {
    let inserted = insert_order(side, size, price, trader);
    if (inserted == false) {return null};
    let final_order = matching(current_order_id);
    current_order_id += 1;
    ?({side = side; size = size; price = price; 
    trader = trader ; order_id = final_order.order_id ; size_left = final_order.size});
  };

  public func cancel_order(order_id_remove : Nat) : async ImmutableOrder{
    order_to_immutable(remove_order(order_id_remove));
  };

  public query func render_orders() : async [ImmutableOrder] {
    Array.map(orders.toArray(), order_to_immutable);
  };

  public query func get_orders_by_trader(trader : Text) : async [ImmutableOrder] {
    switch (user_history.get(trader)) {
      case (null) {
        [];
      };
      case (? user_history) {
        Array.map(List.toArray(List.map(user_history.order_ids, orders.get)), order_to_immutable);
      };
    }
  }
}