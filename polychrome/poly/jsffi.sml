structure jsffi  =
struct

    exception Error of unit
    
    type fptr = string

    structure Name = SStrName;
    structure Tab = Name.NTab;
    open Json.Data
    
    structure arg = struct
        fun string x = [JS x, JS "string"]
        fun real x = [JF x, JS "float"]
        fun bool x = [JB x, JS "bool"]
        fun int x = [JI x, JS "int"]
        fun list x = [JARR x, JS "array"]
        fun object x = [x, JS "object"]
        fun callback x = [JS x, JS "callback"]
        fun null () = [JN, JS "null"]
        fun reference x = [JS x, JS "reference"]
    end
    
    fun send (m) = PolyChrome.send_request m
    fun recv () = PolyChrome.recv_response ()
    
    fun JSONReq t obj f r args = Json.empty
            |> Json.update ("type", JI t)
            |> Json.update ("obj", JS obj)
            |> Json.update ("f", JS f)
            |> Json.update ("r", JB r)
            |> Json.update ("args", JARR (map (fn (x) => JARR (x)) args))
    fun JSONReqStr t obj f r args  = Json.string_of (JSONReq t obj f r args)
    
    fun exec_js obj f args = send (JSONReqStr 2 obj f false args)
    fun exec_js_r obj f args = (send (JSONReqStr 2 obj f true args); recv())
    fun exec_js_set obj f args = send (JSONReqStr 3 obj f false args);
    fun exec_js_get obj f args = (send (JSONReqStr 3 obj f true args); recv())
    
    val readySignal = Json.string_of (Json.empty
            |> Json.update ("type", JI 5)
            |> Json.update ("r", JB false))
    fun ready () = send readySignal
    
    (*Memory management*)
    fun JSONReq2 f r args =
        let
            val x = Json.empty
                 |> Json.update ("type", JI 4) 
                 |> Json.update ("f", JS f)
                 |> Json.update ("r", JB r)
        in
            fold (fn v => fn tab => Json.update ("arg1", v) tab) args x
        end
    fun JSONReqStr2 f r args = Json.string_of (JSONReq2 f r args)
    structure Memory = struct
        fun addFunctionReference f = let
                val _ = send(JSONReqStr2 "addFunctionReference" true [JS f])
            in recv() end
        (* add a function reference that will be used as a callback and is
        overwritable in the event queue *)
        fun addFunctionReferenceOW f = let
                val _ = send(JSONReqStr2 "addFunctionReference" true [JS f, JB true])
            in recv() end
        fun removeReference r = let
                val req = JSONReqStr2 "removeReference" false [JS r]
            in send(req) end
        fun switchDefaultNs () = let
                val req = JSONReqStr2 "switchDefaultNs" false []
            in send(req) end
        fun switchNs (ns) = let
                val req = JSONReqStr2 "switchNs" false [JS ns]
            in send(req) end
        fun clearDefaultNs () = let
                val req = JSONReqStr2 "clearDefaultNs" false []
            in send(req) end
        fun clearNs (ns) = let
                val req = JSONReqStr2 "clearNs" false [JS ns]
            in send(req) end
        fun deleteNs (ns) = let
                val req = JSONReqStr2 "deleteNs" false [JS ns]
            in send(req) end
    end
    
end;