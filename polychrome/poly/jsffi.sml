structure jsffi  =
struct

    exception Error of unit
    
    type fptr = string

    structure Name = SStrName;
    structure Tab = Name.NTab;
    
    structure arg = struct
        fun string x = [Json.String x, Json.String "string"]
        fun real x = [Json.Real x, Json.String "float"]
        fun bool x = [Json.Bool x, Json.String "bool"]
        fun int x = [Json.Int x, Json.String "int"]
        fun list x = [Json.Array x, Json.String "array"]
        fun object x = [x, Json.String "object"]
        fun callback x = [Json.String x, Json.String "callback"]
        fun null () = [Json.Null, Json.String "null"]
        fun reference x = [Json.String x, Json.String "reference"]
    end
    
    fun send (m) = PolyChrome.send_request m
    fun recv () = PolyChrome.recv_response ()
    
    fun JSONReq t obj f r args = Json.empty
            |> Json.update ("type", Json.Int t)
            |> Json.update ("obj", Json.String obj)
            |> Json.update ("f", Json.String f)
            |> Json.update ("r", Json.Bool r)
            |> Json.update ("args", Json.Array (map (fn (x) => Json.Array (x)) args))
    fun JSONReqStr t obj f r args  = Json.string_of (JSONReq t obj f r args)
    
    fun exec_js obj f args = send (JSONReqStr 2 obj f false args)
    fun exec_js_r obj f args = (send (JSONReqStr 2 obj f true args); recv())
    fun exec_js_set obj f args = send (JSONReqStr 3 obj f false args);
    fun exec_js_get obj f args = (send (JSONReqStr 3 obj f true args); recv())
    
    val readySignal = Json.string_of (Json.empty
            |> Json.update ("type", Json.Int 5)
            |> Json.update ("r", Json.Bool false))
    fun ready () = send readySignal
    
    (*Memory management*)
    fun JSONReq2 f r args =
        let
            val x = Json.empty
                 |> Json.update ("type", Json.Int 4) 
                 |> Json.update ("f", Json.String f)
                 |> Json.update ("r", Json.Bool r)
        in
            fold (fn v => fn tab => Json.update ("arg1", v) tab) args x
        end
    fun JSONReqStr2 f r args = Json.string_of (JSONReq2 f r args)
    structure Memory = struct
        fun addFunctionReference f = let
                val _ = send(JSONReqStr2 "addFunctionReference" true [Json.String f])
            in recv() end
        (* add a function reference that will be used as a callback and is
        overwritable in the event queue *)
        fun addFunctionReferenceOW f = let
                val _ = send(JSONReqStr2 "addFunctionReference" true [Json.String f, Json.Bool true])
            in recv() end
        fun removeReference r = let
                val req = JSONReqStr2 "removeReference" false [Json.String r]
            in send(req) end
        fun switchDefaultNs () = let
                val req = JSONReqStr2 "switchDefaultNs" false []
            in send(req) end
        fun switchNs (ns) = let
                val req = JSONReqStr2 "switchNs" false [Json.String ns]
            in send(req) end
        fun clearDefaultNs () = let
                val req = JSONReqStr2 "clearDefaultNs" false []
            in send(req) end
        fun clearNs (ns) = let
                val req = JSONReqStr2 "clearNs" false [Json.String ns]
            in send(req) end
        fun deleteNs (ns) = let
                val req = JSONReqStr2 "deleteNs" false [Json.String ns]
            in send(req) end
    end
    
end;