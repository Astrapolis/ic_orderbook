import Deque "mo:base/Deque";
import Array "mo:base/Array";
import Buffer "mo:base/Buffer";
import TrieMap "mo:base/TrieMap";
import Text "mo:base/Text";
import List "mo:base/List";
import Iter "mo:base/Iter";
import MemoryInfo "memory_info"

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
    user: Text;
    order_id: Nat;
    var size_left : Nat;
  };

  type ImmutableOrder = {
    side: Side;    
    size: Nat;
    price: Nat;
    user: Text;
    order_id: Nat;
    size_left : Nat;
  };


  type Receipt = {
    buy_order_id: Nat;    
    sell_order_id: Nat;
    size: Nat;
  };

  type UserHistory = {
      order_ids : Buffer.Buffer<Nat>;
      receipt_ids : Buffer.Buffer<Nat>;
  };

  type BalanceInBook = {
    var base : Nat;
    var quote : Nat;
  };
  
  type order_result = { #insufficient_fund; #success};

  let orders = Buffer.Buffer<Order>(10000);
  let receipts = Buffer.Buffer<Receipt>(10000);
  let user_history = TrieMap.TrieMap<Text, UserHistory>(Text.equal, Text.hash);
  let user_balance_in_book = TrieMap.TrieMap<Text, BalanceInBook>(Text.equal, Text.hash);
  var current_order_id = 0;
  let max_price = 1000000;
  let price_points : [var Deque.Deque<Nat>]= Array.init(max_price, Deque.empty<Nat>()); 
  var bid_max = 0;
  var ask_min = max_price + 1;

  func check_balance_in_book(user : Text, token : Pair) : ?(Pair, Nat) {
    var balance_in_book = 0;
    switch token {
      case (#base){
        switch (user_history.get(user)) {
          case null {return null;};
          case (?his) {
            for (id in (his.order_ids.vals())){
              let order = orders.get(id);
              if (order.side == #sell){              
                balance_in_book += order.size_left;}
            }
          }
        }
      };
      case (#quote) {
        switch (user_history.get(user)) {
          case null {return null;};
          case (?his) {
            for (id in (his.order_ids.vals())){
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

  func check_available_balance (user : Text, token : Pair) : ?(Nat) {
    var available_balance = 0;
    switch token {
      case (#quote) {
        switch (check_token_balance(user, pair.1)) {
          case (null) {
            return null;
          };
          case (?bal) {
            available_balance := bal;
          }
        };

        switch (user_balance_in_book.get(user)) {
          case null {};
          case (?bal) {
            available_balance := available_balance - bal.quote;
          }
        };
      };
      case (#base) {
        switch (check_token_balance(user, pair.0)) {
          case (null) {
            return null;
          };
          case (?bal) {
            available_balance := bal;
          }
        };
        switch (user_balance_in_book.get(user)) {
          case null {};
          case (?bal) {
            available_balance := available_balance - bal.base;
          }
        };        
      };
    };
    return ?available_balance;
  };

  func insert_order(side: Side, size: Nat, price: Nat, user: Text) : Bool {
    switch side {
      case (#buy) {
        switch (check_available_balance(user, #quote)){
          case null {return false};
          case (?bal) {if (bal < size * price) return false}; 
        };
      };
      case (#sell) {  
        switch (check_available_balance(user, #base)){
          case null {return false};
          case (?bal) {if (bal < size) return false}; 
        };      
      };
    };

    let order : Order = {side = side; size = size; price = price; user = user ; order_id = current_order_id ; var size_left = size};
    orders.add(order);
    switch (user_history.get(user)) {
      case (null) {
        user_history.put(user, {order_ids = Buffer.Buffer<Nat>(100); receipt_ids = Buffer.Buffer<Nat>(100)});
      };
      case (?h) {
        h.order_ids.add(current_order_id);
      }
    };

    switch side {
      case (#buy) {
        switch (user_balance_in_book.get(user)) {
          case null {
            user_balance_in_book.put(user, {var base=0; var quote=size*price});
          };
          case (?bal) {
            bal.quote += size * price;
          }
        }
      };
      case (#sell) {
        switch (user_balance_in_book.get(user)) {
          case null {
            user_balance_in_book.put(user, {var base=size; var quote=0});
          };
          case (?bal) {
            bal.base += size;
          }
        }
      }
    };

    return true;
  };

  func remove_order(order_id_to_cancel : Nat) : ?Order {
    let order = orders.get(order_id_to_cancel);
    if (order.size_left == 0) {return null};

    // split the price point to left and right, search for the order to cancel
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
    let canceled_order = {side = order.side; size : Nat = order.size - order.size_left; price = order.price; user = order.user ; order_id = order.order_id ;  var size_left = 0};

    switch (user_balance_in_book.get(order.user)) {
      case null {return null};
      case (?bal) {
        switch (order.side) {
          case (#buy) {
            bal.quote += order.size_left * order.price;
          };
          case (#sell) {
            bal.base += order.size_left;
          };
        }
      }
    };

    //new price point
    price_points[order.price] := (new_l, new_r);
    orders.put(order_id_to_cancel, canceled_order);
    ?canceled_order;
  };

  func matching_hook(buyer_order : Order, seller_order : Order, size : Nat) : Bool{
    var success = false;
    success := transfer_from_to(pair.1, buyer_order.user, seller_order.user, size*seller_order.price);
    success := transfer_from_to(pair.0, seller_order.user, buyer_order.user, size);

    switch (user_balance_in_book.get(buyer_order.user)) {
      case null {return false};
      case (?bal) {
        bal.quote -= size * buyer_order.price;
      }
    };

    switch (user_balance_in_book.get(seller_order.user)) {
      case null {return false};
      case (?bal) {
        bal.base -= size;
      }
    };   

    receipts.add({ buy_order_id = buyer_order.order_id; sell_order_id = seller_order.order_id; size = size;});
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
    user = order.user ; order_id = order.order_id ; size_left = order.size_left});
  };

  public query func check_available_fund (user : Text, token : Pair) : async ?(Nat) {
    check_available_balance(user, token);
  };

  func limit_order(side: Side, size: Nat, price: Nat, user: Text) : ?ImmutableOrder {
    if (insert_order(side, size, price, user) == false) {return null};
    let final_order = matching(current_order_id);
    current_order_id += 1;
    ?({side = side; size = size; price = price; 
    user = user ; order_id = final_order.order_id ; size_left = final_order.size_left});
  };

  public func buy(size: Nat, price: Nat, user: Text) : async ?ImmutableOrder {
    limit_order(#buy, size, price, user);
  };

  public func sell(size: Nat, price: Nat, user: Text) : async ?ImmutableOrder {
    limit_order(#sell, size, price, user);
  };

  public func cancel_order(order_id_remove : Nat) : async ?ImmutableOrder{
    switch (remove_order(order_id_remove)){
      case null null;
      case (?removed_order) {? order_to_immutable(removed_order)};
    }
  };

  public query func render_orders() : async [ImmutableOrder] {
    Array.map(orders.toArray(), order_to_immutable);
  };

  public query func get_orders_by_user(user : Text) : async [ImmutableOrder] {
    switch (user_history.get(user)) {
      case (null) {
        [];
      };
      case (? user_history) {
        Array.map(Array.map(user_history.order_ids.toArray(), orders.get), order_to_immutable);
      };
    }
  };

  public query func getCanisterMemoryInfo() : async MemoryInfo.CanisterMemoryInfo {
    MemoryInfo.getCanisterMemoryInfo();
  }
}