signature JSFFI =
sig
    type fptr
    
    exception Error of unit
    
    structure Tab : NAME_TAB
    structure Name : SNAME
    
    
    (* this is used in combination with the exec_js_r and exec_js*)
    structure arg :
    sig
        val string : string -> Json.json list
        val reference : fptr -> Json.json list
        val real : real -> Json.json list
        val object : Json.json -> Json.json list
        val null : unit -> Json.json list
        val list : Json.json list -> Json.json list
        val int : int -> Json.json list
        val callback : string -> Json.json list
        val bool : bool -> Json.json list
    end
    
    (* these are used to call JS functions
       when using exec_js_r, it is up to the implementation of the wrapper
       function to convert the returned string to an appropriate type *)
    (* args: an fptr to an object, a function name, an argument list *)
    (* e.g. exec_js_r "document|" "getElementById" [arg.string "something"] *)
    val exec_js_r : string -> string -> Json.json list list -> string
    val exec_js : string -> string -> Json.json list list -> unit
    val exec_js_get : string -> string -> Json.json list list -> string
    val exec_js_set : string -> string -> Json.json list list -> unit
    
    (* this must be called after handling each event *)
    val ready : unit -> unit
    
    (* these are used for keeping the temporary memory, used for
       storing javascript objects, tidy *)
    structure Memory :
    sig
        val switchNs : string -> unit
        val switchDefaultNs : unit -> unit
        val addFunctionReference : string -> fptr
        val addFunctionReferenceOW : string -> fptr
        val removeReference : string -> unit
        val deleteNs : string -> unit
        val clearNs : string -> unit
        val clearDefaultNs : unit -> unit
    end
    
end