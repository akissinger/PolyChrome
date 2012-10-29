structure Console = struct
    fun print (m) =
        let
            val json_obj = Json.mk_object [
                             ("type", Json.Int 0),
                             ("output", Json.String m)]
        in
            PolyChrome.send_request (Json.encode json_obj)
        end
end;