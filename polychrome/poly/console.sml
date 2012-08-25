structure Console = struct
    fun print (m) =
        let
            val json_obj = Json.empty
                        |> Json.update ("type", Json.Int 0)
                        |> Json.update ("output", (Json.String m))
        in
            PolyChrome.send_request (Json.string_of json_obj)
        end
end;