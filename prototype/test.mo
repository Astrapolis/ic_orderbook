import Deque "mo:base/Deque";
import Array "mo:base/Array";
import Buffer "mo:base/Buffer";
import TrieMap "mo:base/TrieMap";
import Text "mo:base/Text";
import List "mo:base/List";
import Iter "mo:base/Iter";
import Debug "mo:base/Debug";

  type Order = {
    var size: Nat;
    price: Nat;
    trader: Text;
    order_id: Nat;
    size_left : Nat;
  };

let h : Order = { var size = 10;
    price = 10;
    trader = "test";
    order_id = 10;
    size_left = 10;};

func change_size(order : Order) {
    order.size := 20;
};

change_size(h);

assert(h.size == 20);

let price_points : [var Deque.Deque<Nat>]= Array.init(100, Deque.empty<Nat>()); 
var a = price_points[10];
a := Deque.pushBack(a, 1);
switch (Deque.peekFront(price_points[10])) {
    case null {};
    case (?val) {
        assert(val == 1);
    }
};

type Pair = {#base: Text; #quote: Text};
let base : Pair = (#base "icp");

switch (base) {
    case (#base token) {
        Debug.print(token);
    };
    case (#quote token) {
        Debug.print(token);
    };
}