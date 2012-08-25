structure Console = struct
    fun print (m) =
        let
            val json_obj = Json.empty
                        |> Json.update ("type", Json.Data.JI 0)
                        |> Json.update ("output", (Json.Data.JS m))
        in
            PolyChrome.send_request (Json.string_of json_obj)
        end
end;