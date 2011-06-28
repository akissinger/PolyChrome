(* just in case cleanup before building the heap *)
PolyML.fullGC();
PolyML.SaveState.loadState "isaplib/heaps/all.polyml-heap";

use "ROOT.ML";
