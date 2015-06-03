open preamble;

val _ = new_theory "closLang";

(* compilation from this language removes closures *)

val max_app_def = Define `
  max_app = 15:num`;

val _ = Datatype `
  op = Global num    (* load global var with index *)
     | SetGlobal num (* assign a value to a global *)
     | AllocGlobal   (* make space for a new global *)
     | Cons num      (* construct a Block with given tag *)
     | El            (* read Block field index *)
     | LengthBlock   (* get length of Block *)
     | Length        (* get length of reference *)
     | LengthByte    (* get length of byte array *)
     | RefByte       (* makes a byte array *)
     | RefArray      (* makes an array by replicating a value *)
     | DerefByte     (* loads a byte from a byte array *)
     | UpdateByte    (* updates a byte array *)
     | FromList num  (* convert list to packed Block *)
     | ToList        (* convert packed Block to list *)
     | TagEq num num (* check Block's tag and length *)
     | IsBlock       (* is it a Block value? *)
     | Ref           (* makes a reference *)
     | Deref         (* loads a value from a reference *)
     | Update        (* updates a reference *)
     | Label num     (* constructs a CodePtr *)
     | FFI num       (* calls the FFI *)
     | Equal         (* structural equality *)
     | Const int     (* integer *)
     | Add           (* + over the integers *)
     | Sub           (* - over the integers *)
     | Mult          (* * over the integers *)
     | Div           (* div over the integers *)
     | Mod           (* mod over the integers *)
     | Less          (* < over the integers *)
     | LessEq        (* <= over the integers *)
     | Greater       (* > over the integers *)
     | GreaterEq     (* >= over the integers *) `

val _ = Datatype `
  exp = Var num
      | If exp exp exp
      | Let (exp list) exp
      | Raise exp
      | Handle exp exp
      | Tick exp
      | Call num (exp list)
      | App (num option) exp (exp list)
      | Fn num (num list) num exp
      | Letrec num (num list) ((num # exp) list) exp
      | Op op (exp list) `;

val exp_size_def = definition"exp_size_def";

val code_locs_def = tDefine "code_locs" `
  (code_locs [] = []) /\
  (code_locs (x::y::xs) =
     let c1 = code_locs [x] in
     let c2 = code_locs (y::xs) in
       c1 ++ c2) /\
  (code_locs [Var v] = []) /\
  (code_locs [If x1 x2 x3] =
     let c1 = code_locs [x1] in
     let c2 = code_locs [x2] in
     let c3 = code_locs [x3] in
       c1 ++ c2 ++ c3) /\
  (code_locs [Let xs x2] =
     let c1 = code_locs xs in
     let c2 = code_locs [x2] in
       c1 ++ c2) /\
  (code_locs [Raise x1] =
     code_locs [x1]) /\
  (code_locs [Tick x1] =
     code_locs [x1]) /\
  (code_locs [Op op xs] =
     code_locs xs) /\
  (code_locs [App loc_opt x1 xs] =
     let c1 = code_locs [x1] in
     let c2 = code_locs xs in
         c1++c2) /\
  (code_locs [Fn loc vs num_args x1] =
     let c1 = code_locs [x1] in
       c1 ++ [loc]) /\
  (code_locs [Letrec loc vs fns x1] =
     let c1 = code_locs (MAP SND fns) in
     let c2 = code_locs [x1] in
     c1 ++ GENLIST ($+ loc) (LENGTH fns) ++ c2) /\
  (code_locs [Handle x1 x2] =
     let c1 = code_locs [x1] in
     let c2 = code_locs [x2] in
       c1 ++ c2) /\
  (code_locs [Call dest xs] =
     code_locs xs)`
  (WF_REL_TAC `measure (exp3_size)`
   \\ REPEAT STRIP_TAC \\ TRY DECIDE_TAC >>
   Induct_on `fns` >>
   srw_tac [ARITH_ss] [exp_size_def] >>
   Cases_on `h` >>
   fs [exp_size_def] >>
   decide_tac);

val code_locs_cons = store_thm("code_locs_cons",
  ``∀x xs. code_locs (x::xs) = code_locs [x] ++ code_locs xs``,
  gen_tac >> Cases >> simp[code_locs_def]);

val contains_App_SOME_def = tDefine "contains_App_SOME" `
  (contains_App_SOME [] ⇔ F) /\
  (contains_App_SOME (x::y::xs) ⇔
     contains_App_SOME [x] ∨
     contains_App_SOME (y::xs)) /\
  (contains_App_SOME [Var v] ⇔ F) /\
  (contains_App_SOME [If x1 x2 x3] ⇔
     contains_App_SOME [x1] ∨
     contains_App_SOME [x2] ∨
     contains_App_SOME [x3]) /\
  (contains_App_SOME [Let xs x2] ⇔
     contains_App_SOME [x2] ∨
     contains_App_SOME xs) /\
  (contains_App_SOME [Raise x1] ⇔
     contains_App_SOME [x1]) /\
  (contains_App_SOME [Tick x1] ⇔
     contains_App_SOME [x1]) /\
  (contains_App_SOME [Op op xs] ⇔
     contains_App_SOME xs) /\
  (contains_App_SOME [App loc_opt x1 x2] ⇔
     IS_SOME loc_opt ∨ max_app < LENGTH x2 ∨
     contains_App_SOME [x1] ∨
     contains_App_SOME x2) /\
  (contains_App_SOME [Fn loc vs num_args x1] ⇔
     contains_App_SOME [x1]) /\
  (contains_App_SOME [Letrec loc vs fns x1] ⇔
     contains_App_SOME (MAP SND fns) ∨
     contains_App_SOME [x1]) /\
  (contains_App_SOME [Handle x1 x2] ⇔
     contains_App_SOME [x1] ∨
     contains_App_SOME [x2]) /\
  (contains_App_SOME [Call dest xs] ⇔
     contains_App_SOME xs)`
  (WF_REL_TAC `measure (exp3_size)`
   \\ REPEAT STRIP_TAC \\ TRY DECIDE_TAC >>
   Induct_on `fns` >>
   srw_tac [ARITH_ss] [exp_size_def] >>
   Cases_on `h` >>
   fs [exp_size_def] >>
   decide_tac);

val contains_App_SOME_EXISTS = store_thm("contains_App_SOME_EXISTS",
  ``∀ls. contains_App_SOME ls ⇔ EXISTS (λx. contains_App_SOME [x]) ls``,
  Induct >> simp[contains_App_SOME_def] >>
  Cases_on`ls`>>fs[contains_App_SOME_def])

val _ = export_theory()
