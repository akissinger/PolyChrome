(*  Title:      Pure/General/table.ML
    Author:     Markus Wenzel and Stefan Berghofer, TU Muenchen

Generic tables.  Efficient purely functional implementation using
balanced 2-3 trees.
*)

signature KEY =
sig
  type key
  val ord: key * key -> order
end;

signature TABLE =
sig
  type key
  type 'a table
  exception DUP of key
  exception SAME
  exception UNDEF of key
  val empty: 'a table
  val is_empty: 'a table -> bool
  val map: ('a -> 'b) -> 'a table -> 'b table
  val map': (key -> 'a -> 'b) -> 'a table -> 'b table
  val fold: (key * 'b -> 'a -> 'a) -> 'b table -> 'a -> 'a
  val fold_rev: (key * 'b -> 'a -> 'a) -> 'b table -> 'a -> 'a
  val dest: 'a table -> (key * 'a) list
  val keys: 'a table -> key list
  val min_key: 'a table -> key option
  val max_key: 'a table -> key option
  val get_first: key option -> (key * 'a -> 'b option) -> 'a table -> 'b option
  val exists: (key * 'a -> bool) -> 'a table -> bool
  val forall: (key * 'a -> bool) -> 'a table -> bool
  val lookup: 'a table -> key -> 'a option
  val defined: 'a table -> key -> bool
  val update: key * 'a -> 'a table -> 'a table
  val update_new: key * 'a -> 'a table -> 'a table                     (*exception DUP*)
  val default: key * 'a -> 'a table -> 'a table
  val map_entry: key -> ('a -> 'a) -> 'a table -> 'a table
  val map_default: key * 'a -> ('a -> 'a) -> 'a table -> 'a table
  val make: (key * 'a) list -> 'a table                                (*exception DUP*)
  val join: (key -> 'a * 'a -> 'a) (*exception DUP/SAME*) ->
    'a table * 'a table -> 'a table                                    (*exception DUP*)
  val merge: ('a * 'a -> bool) -> 'a table * 'a table -> 'a table      (*exception DUP*)
  val delete: key -> 'a table -> 'a table                              (*exception UNDEF*)
  val delete_safe: key -> 'a table -> 'a table
  val member: ('b * 'a -> bool) -> 'a table -> key * 'b -> bool
  val insert: ('a * 'a -> bool) -> key * 'a -> 'a table -> 'a table    (*exception DUP*)
  val remove: ('b * 'a -> bool) -> key * 'b -> 'a table -> 'a table
  val lookup_list: 'a list table -> key -> 'a list
  val cons_list: key * 'a -> 'a list table -> 'a list table
  val insert_list: ('a * 'a -> bool) -> key * 'a -> 'a list table -> 'a list table
  val remove_list: ('b * 'a -> bool) -> key * 'b -> 'a list table -> 'a list table
  val update_list: ('a * 'a -> bool) -> key * 'a -> 'a list table -> 'a list table
  val make_list: (key * 'a) list -> 'a list table
  val dest_list: 'a list table -> (key * 'a) list
  val merge_list: ('a * 'a -> bool) ->
    'a list table * 'a list table -> 'a list table                     (*exception DUP*)
end;

functor Table(Key: KEY): TABLE =
struct


(* datatype table *)

type key = Key.key;

datatype 'a table =
  Empty |
  Branch2 of 'a table * (key * 'a) * 'a table |
  Branch3 of 'a table * (key * 'a) * 'a table * (key * 'a) * 'a table;

exception DUP of key;


(* empty *)

val empty = Empty;

fun is_empty Empty = true
  | is_empty _ = false;


(* map and fold combinators *)

fun map_table f =
  let
    fun map Empty = Empty
      | map (Branch2 (left, (k, x), right)) =
          Branch2 (map left, (k, f k x), map right)
      | map (Branch3 (left, (k1, x1), mid, (k2, x2), right)) =
          Branch3 (map left, (k1, f k1 x1), map mid, (k2, f k2 x2), map right);
  in map end;

fun fold_table f =
  let
    fun fold Empty x = x
      | fold (Branch2 (left, p, right)) x =
          fold right (f p (fold left x))
      | fold (Branch3 (left, p1, mid, p2, right)) x =
          fold right (f p2 (fold mid (f p1 (fold left x))));
  in fold end;

fun fold_rev_table f =
  let
    fun fold Empty x = x
      | fold (Branch2 (left, p, right)) x =
          fold left (f p (fold right x))
      | fold (Branch3 (left, p1, mid, p2, right)) x =
          fold left (f p1 (fold mid (f p2 (fold right x))));
  in fold end;

fun dest tab = fold_rev_table op:: tab [];
fun keys tab = fold_rev_table (op:: o #1) tab [];


(* min/max keys *)

fun min_key Empty = NONE
  | min_key (Branch2 (Empty, (k, _), _)) = SOME k
  | min_key (Branch3 (Empty, (k, _), _, _, _)) = SOME k
  | min_key (Branch2 (left, _, _)) = min_key left
  | min_key (Branch3 (left, _, _, _, _)) = min_key left;

fun max_key Empty = NONE
  | max_key (Branch2 (_, (k, _), Empty)) = SOME k
  | max_key (Branch3 (_, _, _, (k, _), Empty)) = SOME k
  | max_key (Branch2 (_, _, right)) = max_key right
  | max_key (Branch3 (_, _, _, _, right)) = max_key right;


(* get_first *)

fun get_first boundary f tab =
  let
    val check =
      (case boundary of
        NONE => K true
      | SOME b => (fn k => Key.ord (b, k) = LESS));
    fun apply (k, x) = if check k then f (k, x) else NONE;
    fun get_bounded tb k = if check k then get tb else NONE
    and get Empty = NONE
      | get (Branch2 (left, (k, x), right)) =
          (case get_bounded left k of
            NONE =>
              (case apply (k, x) of
                NONE => get right
              | some => some)
          | some => some)
      | get (Branch3 (left, (k1, x1), mid, (k2, x2), right)) =
          (case get_bounded left k1 of
            NONE =>
              (case apply (k1, x1) of
                NONE =>
                  (case get_bounded mid k2 of
                    NONE =>
                      (case apply (k2, x2) of
                        NONE => get right
                      | some => some)
                  | some => some)
              | some => some)
          | some => some);
  in get tab end;

fun exists pred =
  is_some o get_first NONE (fn entry => if pred entry then SOME () else NONE);

fun forall pred = not o exists (not o pred);


(* lookup *)

fun lookup tab key =
  let
    fun look Empty = NONE
      | look (Branch2 (left, (k, x), right)) =
          (case Key.ord (key, k) of
            LESS => look left
          | EQUAL => SOME x
          | GREATER => look right)
      | look (Branch3 (left, (k1, x1), mid, (k2, x2), right)) =
          (case Key.ord (key, k1) of
            LESS => look left
          | EQUAL => SOME x1
          | GREATER =>
              (case Key.ord (key, k2) of
                LESS => look mid
              | EQUAL => SOME x2
              | GREATER => look right));
  in look tab end;

fun defined tab key =
  let
    fun def Empty = false
      | def (Branch2 (left, (k, x), right)) =
          (case Key.ord (key, k) of
            LESS => def left
          | EQUAL => true
          | GREATER => def right)
      | def (Branch3 (left, (k1, x1), mid, (k2, x2), right)) =
          (case Key.ord (key, k1) of
            LESS => def left
          | EQUAL => true
          | GREATER =>
              (case Key.ord (key, k2) of
                LESS => def mid
              | EQUAL => true
              | GREATER => def right));
  in def tab end;


(* modify *)

datatype 'a growth =
  Stay of 'a table |
  Sprout of 'a table * (key * 'a) * 'a table;

exception SAME;

fun modify key f tab =
  let
    fun modfy Empty = Sprout (Empty, (key, f NONE), Empty)
      | modfy (Branch2 (left, p as (k, x), right)) =
          (case Key.ord (key, k) of
            LESS =>
              (case modfy left of
                Stay left' => Stay (Branch2 (left', p, right))
              | Sprout (left1, q, left2) => Stay (Branch3 (left1, q, left2, p, right)))
          | EQUAL => Stay (Branch2 (left, (k, f (SOME x)), right))
          | GREATER =>
              (case modfy right of
                Stay right' => Stay (Branch2 (left, p, right'))
              | Sprout (right1, q, right2) =>
                  Stay (Branch3 (left, p, right1, q, right2))))
      | modfy (Branch3 (left, p1 as (k1, x1), mid, p2 as (k2, x2), right)) =
          (case Key.ord (key, k1) of
            LESS =>
              (case modfy left of
                Stay left' => Stay (Branch3 (left', p1, mid, p2, right))
              | Sprout (left1, q, left2) =>
                  Sprout (Branch2 (left1, q, left2), p1, Branch2 (mid, p2, right)))
          | EQUAL => Stay (Branch3 (left, (k1, f (SOME x1)), mid, p2, right))
          | GREATER =>
              (case Key.ord (key, k2) of
                LESS =>
                  (case modfy mid of
                    Stay mid' => Stay (Branch3 (left, p1, mid', p2, right))
                  | Sprout (mid1, q, mid2) =>
                      Sprout (Branch2 (left, p1, mid1), q, Branch2 (mid2, p2, right)))
              | EQUAL => Stay (Branch3 (left, p1, mid, (k2, f (SOME x2)), right))
              | GREATER =>
                  (case modfy right of
                    Stay right' => Stay (Branch3 (left, p1, mid, p2, right'))
                  | Sprout (right1, q, right2) =>
                      Sprout (Branch2 (left, p1, mid), p2, Branch2 (right1, q, right2)))));

  in
    (case modfy tab of
      Stay tab' => tab'
    | Sprout br => Branch2 br)
    handle SAME => tab
  end;

fun update (key, x) tab = modify key (fn _ => x) tab;
fun update_new (key, x) tab = modify key (fn NONE => x | SOME _ => raise DUP key) tab;
fun default (key, x) tab = modify key (fn NONE => x | SOME _ => raise SAME) tab;
fun map_entry key f = modify key (fn NONE => raise SAME | SOME x => f x);
fun map_default (key, x) f = modify key (fn NONE => f x | SOME y => f y);


(* delete *)

exception UNDEF of key;

local

fun compare NONE (k2, _) = LESS
  | compare (SOME k1) (k2, _) = Key.ord (k1, k2);

fun if_eq EQUAL x y = x
  | if_eq _ x y = y;

fun del (SOME k) Empty = raise UNDEF k
  | del NONE (Branch2 (Empty, p, Empty)) = (p, (true, Empty))
  | del NONE (Branch3 (Empty, p, Empty, q, Empty)) =
      (p, (false, Branch2 (Empty, q, Empty)))
  | del k (Branch2 (Empty, p, Empty)) = (case compare k p of
      EQUAL => (p, (true, Empty)) | _ => raise UNDEF (the k))
  | del k (Branch3 (Empty, p, Empty, q, Empty)) = (case compare k p of
      EQUAL => (p, (false, Branch2 (Empty, q, Empty)))
    | _ => (case compare k q of
        EQUAL => (q, (false, Branch2 (Empty, p, Empty)))
      | _ => raise UNDEF (the k)))
  | del k (Branch2 (l, p, r)) = (case compare k p of
      LESS => (case del k l of
        (p', (false, l')) => (p', (false, Branch2 (l', p, r)))
      | (p', (true, l')) => (p', case r of
          Branch2 (rl, rp, rr) =>
            (true, Branch3 (l', p, rl, rp, rr))
        | Branch3 (rl, rp, rm, rq, rr) => (false, Branch2
            (Branch2 (l', p, rl), rp, Branch2 (rm, rq, rr)))))
    | ord => (case del (if_eq ord NONE k) r of
        (p', (false, r')) => (p', (false, Branch2 (l, if_eq ord p' p, r')))
      | (p', (true, r')) => (p', case l of
          Branch2 (ll, lp, lr) =>
            (true, Branch3 (ll, lp, lr, if_eq ord p' p, r'))
        | Branch3 (ll, lp, lm, lq, lr) => (false, Branch2
            (Branch2 (ll, lp, lm), lq, Branch2 (lr, if_eq ord p' p, r'))))))
  | del k (Branch3 (l, p, m, q, r)) = (case compare k q of
      LESS => (case compare k p of
        LESS => (case del k l of
          (p', (false, l')) => (p', (false, Branch3 (l', p, m, q, r)))
        | (p', (true, l')) => (p', (false, case (m, r) of
            (Branch2 (ml, mp, mr), Branch2 _) =>
              Branch2 (Branch3 (l', p, ml, mp, mr), q, r)
          | (Branch3 (ml, mp, mm, mq, mr), _) =>
              Branch3 (Branch2 (l', p, ml), mp, Branch2 (mm, mq, mr), q, r)
          | (Branch2 (ml, mp, mr), Branch3 (rl, rp, rm, rq, rr)) =>
              Branch3 (Branch2 (l', p, ml), mp, Branch2 (mr, q, rl), rp,
                Branch2 (rm, rq, rr)))))
      | ord => (case del (if_eq ord NONE k) m of
          (p', (false, m')) =>
            (p', (false, Branch3 (l, if_eq ord p' p, m', q, r)))
        | (p', (true, m')) => (p', (false, case (l, r) of
            (Branch2 (ll, lp, lr), Branch2 _) =>
              Branch2 (Branch3 (ll, lp, lr, if_eq ord p' p, m'), q, r)
          | (Branch3 (ll, lp, lm, lq, lr), _) =>
              Branch3 (Branch2 (ll, lp, lm), lq,
                Branch2 (lr, if_eq ord p' p, m'), q, r)
          | (_, Branch3 (rl, rp, rm, rq, rr)) =>
              Branch3 (l, if_eq ord p' p, Branch2 (m', q, rl), rp,
                Branch2 (rm, rq, rr))))))
    | ord => (case del (if_eq ord NONE k) r of
        (q', (false, r')) =>
          (q', (false, Branch3 (l, p, m, if_eq ord q' q, r')))
      | (q', (true, r')) => (q', (false, case (l, m) of
          (Branch2 _, Branch2 (ml, mp, mr)) =>
            Branch2 (l, p, Branch3 (ml, mp, mr, if_eq ord q' q, r'))
        | (_, Branch3 (ml, mp, mm, mq, mr)) =>
            Branch3 (l, p, Branch2 (ml, mp, mm), mq,
              Branch2 (mr, if_eq ord q' q, r'))
        | (Branch3 (ll, lp, lm, lq, lr), Branch2 (ml, mp, mr)) =>
            Branch3 (Branch2 (ll, lp, lm), lq, Branch2 (lr, p, ml), mp,
              Branch2 (mr, if_eq ord q' q, r'))))));

in

fun delete key tab = snd (snd (del (SOME key) tab));
fun delete_safe key tab = delete key tab handle UNDEF _ => tab;

end;


(* membership operations *)

fun member eq tab (key, x) =
  (case lookup tab key of
    NONE => false
  | SOME y => eq (x, y));

fun insert eq (key, x) =
  modify key (fn NONE => x | SOME y => if eq (x, y) then raise SAME else raise DUP key);

fun remove eq (key, x) tab =
  (case lookup tab key of
    NONE => tab
  | SOME y => if eq (x, y) then delete key tab else tab);


(* simultaneous modifications *)

fun make entries = fold update_new entries empty;

fun join f (table1, table2) =
  let fun add (key, y) tab = modify key (fn NONE => y | SOME x => f key (x, y)) tab;
  in if pointer_eq (table1, table2) then table1 else fold_table add table2 table1 end;

fun merge eq = join (fn key => fn xy => if eq xy then raise SAME else raise DUP key);


(* list tables *)

fun lookup_list tab key = these (lookup tab key);

fun cons_list (key, x) tab = modify key (fn NONE => [x] | SOME xs => x :: xs) tab;

fun insert_list eq (key, x) =
  modify key (fn NONE => [x] | SOME xs => if Library.member eq xs x then raise SAME else x :: xs);

fun remove_list eq (key, x) tab =
  map_entry key (fn xs => (case Library.remove eq x xs of [] => raise UNDEF key | ys => ys)) tab
  handle UNDEF _ => delete key tab;

fun update_list eq (key, x) =
  modify key (fn NONE => [x] | SOME [] => [x] | SOME (xs as y :: _) =>
    if eq (x, y) then raise SAME else Library.update eq x xs);

fun make_list args = fold_rev cons_list args empty;
fun dest_list tab = maps (fn (key, xs) => map (pair key) xs) (dest tab);
fun merge_list eq = join (fn _ => Library.merge eq);


(*final declarations of this structure!*)
fun map f = map_table (K f);
val map' = map_table;
val fold = fold_table;
val fold_rev = fold_rev_table;

end;

structure Inttab = Table(type key = int val ord = int_ord);
structure Symtab = Table(type key = string val ord = fast_string_ord);
structure Symreltab = Table(type key = string * string
  val ord = prod_ord fast_string_ord fast_string_ord);

