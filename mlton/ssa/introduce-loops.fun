(* Copyright (C) 1999-2002 Henry Cejtin, Matthew Fluet, Suresh
 *    Jagannathan, and Stephen Weeks.
 * Copyright (C) 1997-1999 NEC Research Institute.
 *
 * MLton is released under the GNU General Public License (GPL).
 * Please see the file MLton-LICENSE for license information.
 *)
(* Change any toplevel function that only calls itself in tail position
 * into one with a local loop and no self calls.
 *)
functor IntroduceLoops (S: INTRODUCE_LOOPS_STRUCTS): INTRODUCE_LOOPS = 
struct

open S
datatype z = datatype Exp.t
datatype z = datatype Transfer.t

structure Return =
   struct
      open Return

      (* Can't use the usual definition of isTail because it includes Dead,
       * which we can't turn into loops because the profile stack might be off.
       *)
      fun isTail (z: t): bool =
	 case z of
	    Dead => false
	  | HandleOnly => true
	  | NonTail _ => false
	  | Tail => true
   end

fun introduceLoops (Program.T {datatypes, globals, functions, main}) =
   let
      val functions =
	 List.map
	 (functions, fn f =>
	  let
	     val {args, blocks, name, raises, returns, start} = Function.dest f
	     val tailCallsItself = ref false
	     val _ =
		Vector.foreach
		(blocks, fn Block.T {transfer, ...} =>
		 case transfer of
		    Call {func, return, ...} =>
		       if Func.equals (name, func)
			  andalso Return.isTail return
			  then tailCallsItself := true
		       else ()
		  | _ => ())
	     val (args, start, blocks) =
		if !tailCallsItself
		   then
		      let
			 val _ = Control.diagnostics
			    (fn display =>
			     let open Layout
			     in
				display (Func.layout name)
			     end)
			 val newArgs =
			    Vector.map (args, fn (x, t) => (Var.new x, t))
			 val loopName = Label.newString "loop"
			 val loopSName = Label.newString "loopS"
			 val blocks = 
			    Vector.toListMap
			    (blocks,
			     fn Block.T {label, args, statements, transfer} =>
			     let
				val transfer =
				   case transfer of
				      Call {func, args, return} =>
					 if Func.equals (name, func)
					    andalso Return.isTail return
					    then Goto {dst = loopName, 
						       args = args}
					 else transfer
				    | _ => transfer
			     in
				Block.T {label = label,
					 args = args,
					 statements = statements,
					 transfer = transfer}
			     end)
			 val blocks = 
			    Vector.fromList
			    (Block.T 
			     {label = loopSName,
			      args = Vector.new0 (),
			      statements = Vector.new0 (),
			      transfer = Goto {dst = loopName,
					       args = Vector.map (newArgs, #1)}} ::
			     Block.T 
			     {label = loopName,
			      args = args,
			      statements = Vector.new0 (),
			      transfer = Goto {dst = start,
					       args = Vector.new0 ()}} ::
			     blocks)
		      in
			 (newArgs,
			  loopSName,
			  blocks)
		      end
		else (args, start, blocks)
	  in
	     Function.new {args = args,
			   blocks = blocks,
			   name = name,
			   raises = raises,
			   returns = returns,
			   start = start}
	  end)
   in
      Program.T {datatypes = datatypes,
		 globals = globals,
		 functions = functions,
		 main = main}
   end

end
