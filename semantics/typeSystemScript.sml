(*Generated by Lem from typeSystem.lem.*)
open HolKernel Parse boolLib bossLib;
open lem_pervasives_extraTheory libTheory astTheory semanticPrimitivesTheory;

val _ = numLib.prefer_num();



val _ = new_theory "typeSystem"

(*open import Pervasives_extra*)
(*open import Lib*)
(*open import Ast*)
(*open import SemanticPrimitives*)

(* Check that the free type variables are in the given list. Every deBruijn
 * variable must be smaller than the first argument. So if it is 0, no deBruijn
 * indices are permitted. *)
(*val check_freevars : nat -> list tvarN -> t -> bool*)
 val check_freevars_defn = Hol_defn "check_freevars" `

(check_freevars dbmax tvs (Tvar tv) =  
(MEM tv tvs))
/\
(check_freevars dbmax tvs (Tapp ts tn) =  
(EVERY (check_freevars dbmax tvs) ts))
/\
(check_freevars dbmax tvs (Tvar_db n) = (n < dbmax))`;

val _ = Lib.with_flag (computeLib.auto_import_definitions, false) Defn.save_defn check_freevars_defn;

(* Simultaneous substitution of types for type variables in a type *)
(*val type_subst : Map.map tvarN t -> t -> t*)
 val type_subst_defn = Hol_defn "type_subst" `

(type_subst s (Tvar tv) =  
((case FLOOKUP s tv of
      NONE => Tvar tv
    | SOME(t) => t
  )))
/\
(type_subst s (Tapp ts tn) =  
(Tapp (MAP (type_subst s) ts) tn))
/\
(type_subst s (Tvar_db n) = (Tvar_db n))`;

val _ = Lib.with_flag (computeLib.auto_import_definitions, false) Defn.save_defn type_subst_defn;

(* Increment the deBruijn indices in a type by n levels, skipping all levels
 * less than skip. *)
(*val deBruijn_inc : nat -> nat -> t -> t*)
 val deBruijn_inc_defn = Hol_defn "deBruijn_inc" `

(deBruijn_inc skip n (Tvar tv) = (Tvar tv))
/\
(deBruijn_inc skip n (Tvar_db m) =  
(if m < skip then
    Tvar_db m
  else
    Tvar_db (m + n)))
/\
(deBruijn_inc skip n (Tapp ts tn) = (Tapp (MAP (deBruijn_inc skip n) ts) tn))`;

val _ = Lib.with_flag (computeLib.auto_import_definitions, false) Defn.save_defn deBruijn_inc_defn;

(* skip the lowest given indices and replace the next (LENGTH ts) with the given types and reduce all the higher ones *)
(*val deBruijn_subst : nat -> list t -> t -> t*)
 val deBruijn_subst_defn = Hol_defn "deBruijn_subst" `

(deBruijn_subst skip ts (Tvar tv) = (Tvar tv))
/\
(deBruijn_subst skip ts (Tvar_db n) =  
(if ~ (n < skip) /\ (n < (LENGTH ts + skip)) then
    EL (n - skip) ts
  else if ~ (n < skip) then
    Tvar_db (n - LENGTH ts)
  else
    Tvar_db n))
/\
(deBruijn_subst skip ts (Tapp ts' tn) =  
(Tapp (MAP (deBruijn_subst skip ts) ts') tn))`;

val _ = Lib.with_flag (computeLib.auto_import_definitions, false) Defn.save_defn deBruijn_subst_defn;

(* flat_tenv_ctor is kept as an alist rather than a map because in the type
 * soundness proof, we sometimes need to look at all defined constructors, even
 * those shadowed by a later definition *)
val _ = type_abbrev( "flat_tenv_ctor" , ``: (conN, ( tvarN list # t list # tid_or_exn)) alist``);
val _ = type_abbrev( "tenv_ctor" , ``: (conN, ( tvarN list # t list # tid_or_exn)) alist_mod_env``);

val _ = type_abbrev((* ( 'k, 'v) *) "mod_env" , ``: (modN, ( ('k, 'v)fmap)) fmap # ('k, 'v) fmap``);

val _ = Define `
 (merge_mod_env (menv1,env1) (menv2,env2) =
  (FUNION menv1 menv2, FUNION env1 env2))`;


val _ = Define `
 (lookup_mod_env id (mcenv,cenv) =  
((case id of
      Short x => FLOOKUP cenv x
    | Long x y =>
        (case FLOOKUP mcenv x of
            NONE => NONE
          | SOME cenv => FLOOKUP cenv y
        )
  )))`;


(* Type environments *)
(* This is a list-like structure, rather than a finite map because the
 * Bind_tvar constructor makes the ordering relevant *)
val _ = Hol_datatype `
 tenv_val =
    Empty
  (* Binds several de Bruijn type variables *)
  | Bind_tvar of num => tenv_val
  (* The number is how many de Bruijn type variables the typescheme binds *)
  | Bind_name of varN => num => t => tenv_val`;


(*val bind_tvar : nat -> tenv_val -> tenv_val*)
val _ = Define `
 (bind_tvar tvs tenv_val = (if tvs = 0 then tenv_val else Bind_tvar tvs tenv_val))`;


(* Type environments without any binding, but still an alist rather than a map,
 * so that they can be added to tenv_vals *)
val _ = type_abbrev( "flat_tenv_val" , ``: (varN, (num # t)) alist``);

val _ = Hol_datatype `
 type_environment =
  <| m : (modN, ( (varN, (num # t))alist)) fmap
   ; c : tenv_ctor
   ; v : tenv_val
   ; t : (typeN, ( tvarN list # t)) mod_env
   |>`;


(*val lookup_tenv_val : varN -> nat -> tenv_val -> maybe (nat * t)*)
 val _ = Define `

(lookup_tenv_val n inc Empty = NONE)
/\
(lookup_tenv_val n inc (Bind_tvar tvs tenv_val) = (lookup_tenv_val n (inc + tvs) tenv_val))
/\
(lookup_tenv_val n inc (Bind_name n' tvs t tenv_val) =  
(if n' = n then
    SOME (tvs, deBruijn_inc tvs inc t)
  else
    lookup_tenv_val n inc tenv_val))`;


(*val opt_bind_name : maybe varN -> nat -> t -> tenv_val -> tenv_val*)
val _ = Define `
 (opt_bind_name n tvs t tenv_val =  
((case n of
      NONE => tenv_val
    | SOME n' => Bind_name n' tvs t tenv_val
  )))`;


(*val t_lookup_var_id : id varN -> type_environment -> maybe (nat * t)*)
val _ = Define `
 (t_lookup_var_id id tenv =  
((case id of
      Short x => lookup_tenv_val x( 0) tenv.v
    | Long x y =>
        (case FLOOKUP tenv.m x of
            NONE => NONE
          | SOME flat_tenv_val => ALOOKUP flat_tenv_val y
        )
  )))`;


(*val num_tvs : tenv_val -> nat*)
 val _ = Define `

(num_tvs Empty =( 0))
/\
(num_tvs (Bind_tvar tvs tenv_val) = (tvs + num_tvs tenv_val))
/\
(num_tvs (Bind_name n tvs t tenv_val) = (num_tvs tenv_val))`;


(*val bind_var_list : nat -> list (varN * t) -> tenv_val -> tenv_val*)
 val _ = Define `

(bind_var_list tvs [] tenv_val = tenv_val)
/\
(bind_var_list tvs ((n,t)::binds) tenv_val =  
(Bind_name n tvs t (bind_var_list tvs binds tenv_val)))`;


(*val bind_var_list2 : list (varN * (nat * t)) -> tenv_val -> tenv_val*)
 val _ = Define `

(bind_var_list2 [] tenv_val = tenv_val)
/\
(bind_var_list2 ((n,(tvs,t))::binds) tenv_val =  
(Bind_name n tvs t (bind_var_list2 binds tenv_val)))`;


(* A pattern matches values of a certain type and extends the type environment
 * with the pattern's binders. The number is the maximum deBruijn type variable
 * allowed. *)
(*val type_p : nat -> tenv_ctor -> pat -> t -> list (varN * t) -> bool*)

(* An expression has a type *)
(*val type_e : type_environment -> exp -> t -> bool*)

(* A list of expressions has a list of types *)
(*val type_es : type_environment -> list exp -> list t -> bool*)

(* Type a mutually recursive bundle of functions.  Unlike pattern typing, the
 * resulting environment does not extend the input environment, but just
 * represents the functions *)
(*val type_funs : type_environment -> list (varN * varN * exp) -> list (varN * t) -> bool*)

val _ = Hol_datatype `
 decls =
  <| defined_mods : modN set;
     defined_types : ( typeN id) set;
     defined_exns : ( conN id) set |>`;


(*val empty_decls : decls*)
val _ = Define `
 (empty_decls = (<|defined_mods := {}; defined_types := {}; defined_exns := {}|>))`;


(*val union_decls : decls -> decls -> decls*)
val _ = Define `
 (union_decls d1 d2 =  
(<| defined_mods := (d1.defined_mods UNION d2.defined_mods);
     defined_types := (d1.defined_types UNION d2.defined_types);
     defined_exns := (d1.defined_exns UNION d2.defined_exns) |>))`;


val _ = type_abbrev( "flat_tenv_tabbrev" , ``: (typeN, ( tvarN list # t)) fmap``);
val _ = type_abbrev( "tenv_tabbrev" , ``: (typeN, ( tvarN list # t)) mod_env``);

val _ = type_abbrev( "new_dec_tenv" , ``: flat_tenv_tabbrev # flat_tenv_ctor # flat_tenv_val``);

(*val append_new_dec_tenv : new_dec_tenv -> new_dec_tenv -> new_dec_tenv*)
val _ = Define `
 (append_new_dec_tenv (t1,c1,v1) (t2,c2,v2) =
  (FUNION t1 t2,(c1++c2),(v1++v2)))`;


(*val extend_env_new_decs : new_dec_tenv -> type_environment -> type_environment*)
val _ = Define `
 (extend_env_new_decs (t,c,v) tenv =  
(<| m := tenv.m;
     c := (merge_alist_mod_env ([],c) tenv.c);
     v := (bind_var_list2 v tenv.v);
     t := (merge_mod_env (FEMPTY,t) tenv.t) |>))`;


val _ = type_abbrev( "new_top_tenv" , ``: tenv_tabbrev # (modN, ( (varN, (num # t))alist)) fmap # tenv_ctor # flat_tenv_val``);

(*val append_new_top_tenv : new_top_tenv -> new_top_tenv -> new_top_tenv*)
val _ = Define `
 (append_new_top_tenv (t1,m1,c1,v1) (t2,m2,c2,v2) =
  (merge_mod_env t1 t2,FUNION m1 m2,merge_alist_mod_env c1 c2,(v1++v2)))`;


(*val extend_env_new_tops : new_top_tenv -> type_environment -> type_environment*)
val _ = Define `
 (extend_env_new_tops (t,m,c,v) tenv =  
(<| t := (merge_mod_env t tenv.t);
     m := (FUNION m tenv.m);
     c := (merge_alist_mod_env c tenv.c);
     v := (bind_var_list2 v tenv.v) |>))`;


(* Check a declaration and update the top-level environments
 * The arguments are in order:
 * - the module that the declaration is in
 * - the set of all modules, and types, and exceptions that have been previously declared
 * - the type environment
 * - the declaration
 * - the set of all modules, and types, and exceptions that are declared here
 * - the types of new type operator names and abbreviations
 * - the types of the new constructors
 * - the type schemes of the new bindings *)

(*val type_d : bool -> maybe modN -> decls -> type_environment -> dec -> decls -> new_dec_tenv -> bool*)

(*val type_ds : bool -> maybe modN -> decls -> type_environment -> list dec -> decls -> new_dec_tenv -> bool*)
(*val weakE : flat_tenv_val -> flat_tenv_val -> bool*)
(*val check_signature : maybe modN -> tenv_tabbrev -> decls -> new_dec_tenv -> maybe specs -> decls -> new_dec_tenv -> bool*)
(*val type_specs : maybe modN -> tenv_tabbrev -> specs -> decls -> new_dec_tenv -> bool*)
(*val type_prog : bool -> decls -> type_environment -> list top -> decls -> new_top_tenv -> bool*)

(* Check that the operator can have type (t1 -> ... -> tn -> t) *)
(*val type_op : op -> list t -> t -> bool*)
val _ = Define `
 (type_op op ts t =  
((case (op,ts) of
      (Opapp, [Tapp [t2'; t3'] TC_fn; t2]) => (t2 = t2') /\ (t = t3')
    | (Opn _, [Tapp [] TC_int; Tapp [] TC_int]) => (t = Tint)
    | (Opb _, [Tapp [] TC_int; Tapp [] TC_int]) => (t = Tapp [] (TC_name (Short "bool")))
    | (Opw W8 _, [Tapp [] TC_word8; Tapp [] TC_word8]) => (t = Tapp [] TC_word8)
    | (Opw W64 _, [Tapp [] TC_word64; Tapp [] TC_word64]) => (t = Tapp [] TC_word64)
    | (Shift W8 _ _, [Tapp [] TC_word8]) => (t = Tapp [] TC_word8)
    | (Shift W64 _ _, [Tapp [] TC_word64]) => (t = Tapp [] TC_word64)
    | (Equality, [t1; t2]) => (t1 = t2) /\ (t = Tapp [] (TC_name (Short "bool")))
    | (Opassign, [Tapp [t1] TC_ref; t2]) => (t1 = t2) /\ (t = Tapp [] TC_tup)
    | (Opref, [t1]) => (t = Tapp [t1] TC_ref)
    | (Opderef, [Tapp [t1] TC_ref]) => (t = t1)
    | (Aw8alloc, [Tapp [] TC_int; Tapp [] TC_word8]) => (t = Tapp [] TC_word8array)
    | (Aw8sub, [Tapp [] TC_word8array; Tapp [] TC_int]) => (t = Tapp [] TC_word8)
    | (Aw8length, [Tapp [] TC_word8array]) => (t = Tapp [] TC_int)
    | (Aw8update, [Tapp [] TC_word8array; Tapp [] TC_int; Tapp [] TC_word8]) => t = Tapp [] TC_tup
    | (WordFromInt W8, [Tapp [] TC_int]) => t = Tapp [] TC_word8
    | (WordToInt W8, [Tapp [] TC_word8]) => t = Tapp [] TC_int
    | (WordFromInt W64, [Tapp [] TC_int]) => t = Tapp [] TC_word64
    | (WordToInt W64, [Tapp [] TC_word64]) => t = Tapp [] TC_int
    | (Chr, [Tapp [] TC_int]) => (t = Tchar)
    | (Ord, [Tapp [] TC_char]) => (t = Tint)
    | (Chopb _, [Tapp [] TC_char; Tapp [] TC_char]) => (t = Tapp [] (TC_name (Short "bool")))
    | (Explode, [Tapp [] TC_string]) => t = Tapp [Tapp [] TC_char] (TC_name (Short "list"))
    | (Implode, [Tapp [Tapp [] TC_char] (TC_name (Short "list"))]) => t = Tapp [] TC_string
    | (Strlen, [Tapp [] TC_string]) => t = Tint
    | (VfromList, [Tapp [t1] (TC_name (Short "list"))]) => t = Tapp [t1] TC_vector
    | (Vsub, [Tapp [t1] TC_vector; Tapp [] TC_int]) => t = t1
    | (Vlength, [Tapp [t1] TC_vector]) => (t = Tapp [] TC_int)
    | (Aalloc, [Tapp [] TC_int; t1]) => t = Tapp [t1] TC_array
    | (Asub, [Tapp [t1] TC_array; Tapp [] TC_int]) => t = t1
    | (Alength, [Tapp [t1] TC_array]) => t = Tapp [] TC_int
    | (Aupdate, [Tapp [t1] TC_array; Tapp [] TC_int; t2]) => (t1 = t2) /\ (t = Tapp [] TC_tup)
    | (FFI n, [Tapp [] TC_word8array]) => t = Tapp [] TC_tup
    | _ => F
  )))`;


(*val check_type_names : tenv_tabbrev -> t -> bool*)
 val check_type_names_defn = Hol_defn "check_type_names" `

(check_type_names tenv_tabbrev (Tvar tv) =
  T)
/\
(check_type_names tenv_tabbrev (Tapp ts tn) =  
((case tn of
     TC_name tn =>
       (case lookup_mod_env tn tenv_tabbrev of
           SOME (tvs, t) => LENGTH tvs = LENGTH ts
         | NONE => F
       )
   | _ => T
  ) /\
  EVERY (check_type_names tenv_tabbrev) ts))
/\
(check_type_names tenv_tabbrev (Tvar_db n) =
  T)`;

val _ = Lib.with_flag (computeLib.auto_import_definitions, false) Defn.save_defn check_type_names_defn;

(* Substitution of type names for the type they abbreviate *)
(*val type_name_subst : tenv_tabbrev -> t -> t*)
 val type_name_subst_defn = Hol_defn "type_name_subst" `

(type_name_subst tenv_tabbrev (Tvar tv) = (Tvar tv))
/\
(type_name_subst tenv_tabbrev (Tapp ts tc) =  
(let args = (MAP (type_name_subst tenv_tabbrev) ts) in
    (case tc of
        TC_name tn =>
          (case lookup_mod_env tn tenv_tabbrev of
              SOME (tvs, t) => type_subst (alist_to_fmap (ZIP (tvs, args))) t
            | NONE => Tapp args tc
          )
      | _ => Tapp args tc
    )))
/\
(type_name_subst tenv_tabbrev (Tvar_db n) = (Tvar_db n))`;

val _ = Lib.with_flag (computeLib.auto_import_definitions, false) Defn.save_defn type_name_subst_defn;

(* Check that a type definition defines no already defined types or duplicate
 * constructors, and that the free type variables of each constructor argument
 * type are included in the type's type parameters. Also check that all of the
 * types mentioned are in scope. *)
(*val check_ctor_tenv :
   maybe modN -> tenv_tabbrev -> list (list tvarN * typeN * list (conN * list t)) -> bool*)
val _ = Define `
 (check_ctor_tenv mn tenv_tabbrev tds =  
(check_dup_ctors tds /\
  EVERY
    (\ (tvs,tn,ctors) . 
       ALL_DISTINCT tvs /\
       EVERY
         (\ (cn,ts) .  EVERY (check_freevars( 0) tvs) ts /\ EVERY (check_type_names tenv_tabbrev) ts)
         ctors)
    tds /\
  ALL_DISTINCT (MAP (\p .  
  (case (p ) of ( (_,tn,_) ) => tn )) tds)))`;


(*val build_ctor_tenv : maybe modN -> tenv_tabbrev -> list (list tvarN * typeN * list (conN * list t)) -> flat_tenv_ctor*)
val _ = Define `
 (build_ctor_tenv mn tenv_tabbrev tds =  
(REVERSE
    (FLAT
      (MAP
         (\ (tvs,tn,ctors) . 
            MAP (\ (cn,ts) .  (cn,(tvs,MAP (type_name_subst tenv_tabbrev) ts, TypeId (mk_id mn tn)))) ctors)
         tds))))`;


(* Check that an exception definition defines no already defined (or duplicate)
 * constructors, and that the arguments have no free type variables. *)
(*val check_exn_tenv : maybe modN -> conN -> list t -> bool*)
val _ = Define `
 (check_exn_tenv mn cn ts =  
(EVERY (check_freevars( 0) []) ts))`;


(* For the value restriction on let-based polymorphism *)
(*val is_value : exp -> bool*)
 val is_value_defn = Hol_defn "is_value" `

(is_value (Lit _) = T)
/\
(is_value (Con _ es) = (EVERY is_value es))
/\
(is_value (Var _) = T)
/\
(is_value (Fun _ _) = T)
/\
(is_value _ = F)`;

val _ = Lib.with_flag (computeLib.auto_import_definitions, false) Defn.save_defn is_value_defn;

(*val tid_exn_to_tc : tid_or_exn -> tctor*)
val _ = Define `
 (tid_exn_to_tc t =  
((case t of
      TypeId tid => TC_name tid
    | TypeExn _ => TC_exn
  )))`;


val _ = Hol_reln ` (! tvs tenv_ctor n t.
(check_freevars tvs [] t)
==>
type_p tvs tenv_ctor (Pvar n) t [(n,t)])

/\ (! tvs tenv_ctor n.
T
==>
type_p tvs tenv_ctor (Plit (IntLit n)) Tint [])

/\ (! tvs tenv_ctor c.
T
==>
type_p tvs tenv_ctor (Plit (Char c)) Tchar [])

/\ (! tvs tenv_ctor s.
T
==>
type_p tvs tenv_ctor (Plit (StrLit s)) Tstring [])

/\ (! tvs tenv_ctor w.
T
==>
type_p tvs tenv_ctor (Plit (Word8 w)) Tword8 [])

/\ (! tvs tenv_ctor w.
T
==>
type_p tvs tenv_ctor (Plit (Word64 w)) Tword64 [])

/\ (! tvs tenv_ctor cn ps ts tvs' tn ts' bindings.
(EVERY (check_freevars tvs []) ts' /\
(LENGTH ts' = LENGTH tvs') /\
type_ps tvs tenv_ctor ps (MAP (type_subst (alist_to_fmap (ZIP (tvs', ts')))) ts) bindings /\
(lookup_alist_mod_env cn tenv_ctor = SOME (tvs', ts, tn)))
==>
type_p tvs tenv_ctor (Pcon (SOME cn) ps) (Tapp ts' (tid_exn_to_tc tn)) bindings)

/\ (! tvs tenv_ctor ps ts bindings.
(type_ps tvs tenv_ctor ps ts bindings)
==>
type_p tvs tenv_ctor (Pcon NONE ps) (Tapp ts TC_tup) bindings)

/\ (! tvs tenv_ctor p t bindings.
(type_p tvs tenv_ctor p t bindings)
==>
type_p tvs tenv_ctor (Pref p) (Tref t) bindings)

/\ (! tvs tenv_ctor.
T
==>
type_ps tvs tenv_ctor [] [] [])

/\ (! tvs tenv_ctor p ps t ts bindings bindings'.
(type_p tvs tenv_ctor p t bindings /\
type_ps tvs tenv_ctor ps ts bindings')
==>
type_ps tvs tenv_ctor (p::ps) (t::ts) (bindings'++bindings))`;

val _ = Hol_reln ` (! tenv n.
T
==>
type_e tenv (Lit (IntLit n)) Tint)

/\ (! tenv c.
T
==>
type_e tenv (Lit (Char c)) Tchar)

/\ (! tenv s.
T
==>
type_e tenv (Lit (StrLit s)) Tstring)

/\ (! tenv w.
T
==>
type_e tenv (Lit (Word8 w)) Tword8)

/\ (! tenv w.
T
==>
type_e tenv (Lit (Word64 w)) Tword64)

/\ (! tenv e t.
(check_freevars (num_tvs tenv.v) [] t /\
type_e tenv e Texn)
==>
type_e tenv (Raise e) t)

/\ (! tenv e pes t.
(type_e tenv e t /\ ~ (pes = []) /\
(! ((p,e) :: LIST_TO_SET pes). ? bindings.
   ALL_DISTINCT (pat_bindings p []) /\
   type_p (num_tvs tenv.v) tenv.c p Texn bindings /\
   type_e (tenv with<| v := bind_var_list( 0) bindings tenv.v|>) e t))
==>
type_e tenv (Handle e pes) t)

/\ (! tenv cn es tvs tn ts' ts.
(EVERY (check_freevars (num_tvs tenv.v) []) ts' /\
(LENGTH tvs = LENGTH ts') /\
type_es tenv es (MAP (type_subst (alist_to_fmap (ZIP (tvs, ts')))) ts) /\
(lookup_alist_mod_env cn tenv.c = SOME (tvs, ts, tn)))
==>
type_e tenv (Con (SOME cn) es) (Tapp ts' (tid_exn_to_tc tn)))

/\ (! tenv es ts.
(type_es tenv es ts)
==>
type_e tenv (Con NONE es) (Tapp ts TC_tup))

/\ (! tenv n t targs tvs.
((tvs = LENGTH targs) /\
EVERY (check_freevars (num_tvs tenv.v) []) targs /\
(t_lookup_var_id n tenv = SOME (tvs,t)))
==>
type_e tenv (Var n) (deBruijn_subst( 0) targs t))

/\ (! tenv n e t1 t2.
(check_freevars (num_tvs tenv.v) [] t1 /\
type_e (tenv with<| v := Bind_name n( 0) t1 tenv.v|>) e t2)
==>
type_e tenv (Fun n e) (Tfn t1 t2))

/\ (! tenv op es ts t.
(type_es tenv es ts /\
type_op op ts t)
==>
type_e tenv (App op es) t)

/\ (! tenv l e1 e2.
(type_e tenv e1 (Tapp [] (TC_name (Short "bool"))) /\
type_e tenv e2 (Tapp [] (TC_name (Short "bool"))))
==>
type_e tenv (Log l e1 e2) (Tapp [] (TC_name (Short "bool"))))

/\ (! tenv e1 e2 e3 t.
(type_e tenv e1 (Tapp [] (TC_name (Short "bool"))) /\
type_e tenv e2 t /\
type_e tenv e3 t)
==>
type_e tenv (If e1 e2 e3) t)

/\ (! tenv e pes t1 t2.
(type_e tenv e t1 /\ ~ (pes = []) /\
(! ((p,e) :: LIST_TO_SET pes) . ? bindings.
   ALL_DISTINCT (pat_bindings p []) /\
   type_p (num_tvs tenv.v) tenv.c p t1 bindings /\
   type_e (tenv with<| v := bind_var_list( 0) bindings tenv.v|>) e t2))
==>
type_e tenv (Mat e pes) t2)

/\ (! tenv n e1 e2 t1 t2.
(type_e tenv e1 t1 /\
type_e (tenv with<| v := opt_bind_name n( 0) t1 tenv.v|>) e2 t2)
==>
type_e tenv (Let n e1 e2) t2)

(*
and

letrec : forall tenv funs e t tenv' tvs.
type_funs (bind_var_list 0 tenv' (bind_tvar tvs tenv)) funs tenv' &&
type_e (bind_var_list tvs tenv' tenv) e t
==>
type_e tenv (Letrec funs e) t
*)

/\ (! tenv funs e t bindings.
(type_funs (tenv with<| v := bind_var_list( 0) bindings tenv.v|>) funs bindings /\
type_e (tenv with<| v := bind_var_list( 0) bindings tenv.v|>) e t)
==>
type_e tenv (Letrec funs e) t)

/\ (! tenv.
T
==>
type_es tenv [] [])

/\ (! tenv e es t ts.
(type_e tenv e t /\
type_es tenv es ts)
==>
type_es tenv (e::es) (t::ts))

/\ (! tenv.
T
==>
type_funs tenv [] [])

/\ (! tenv fn n e funs bindings t1 t2.
(check_freevars (num_tvs tenv.v) [] (Tfn t1 t2) /\
type_e (tenv with<| v := Bind_name n( 0) t1 tenv.v|>) e t2 /\
type_funs tenv funs bindings /\
(ALOOKUP bindings fn = NONE))
==>
type_funs tenv ((fn, n, e)::funs) ((fn, Tfn t1 t2)::bindings))`;

(*val tenv_add_tvs : nat -> alist varN t -> flat_tenv_val*)
val _ = Define `
 (tenv_add_tvs tvs tenv =  
(MAP (\ (n,t) .  (n,(tvs,t))) tenv))`;


(*val type_pe_determ : type_environment -> pat -> exp -> bool*)
val _ = Define `
 (type_pe_determ tenv p e =  
(! t1 tenv1 t2 tenv2.    
(type_p( 0) tenv.c p t1 tenv1 /\ type_e tenv e t1 /\
    type_p( 0) tenv.c p t2 tenv2 /\ type_e tenv e t2)
    ==>    
(tenv1 = tenv2)))`;


val _ = Define `
 (weakE tenv_impl tenv_spec =  
(! x.
    (case ALOOKUP tenv_spec x of
        SOME (tvs_spec, t_spec) =>
          (case ALOOKUP tenv_impl x of
              NONE => F
            | SOME (tvs_impl, t_impl) =>
                ? subst.                  
(LENGTH subst = tvs_impl) /\
                  check_freevars tvs_impl [] t_impl /\
                  EVERY (check_freevars tvs_spec []) subst /\                  
(deBruijn_subst( 0) subst t_impl = t_spec)
          )
        | NONE => T
    )))`;



val _ = Hol_reln ` (! extra_checks tvs mn tenv p e t bindings decls.
(is_value e /\
ALL_DISTINCT (pat_bindings p []) /\
type_p tvs tenv.c p t bindings /\
type_e (tenv with<| v := bind_tvar tvs tenv.v|>) e t /\
(extra_checks ==>  
(! tvs' bindings' t'.    
(type_p tvs' tenv.c p t' bindings' /\
    type_e (tenv with<| v := bind_tvar tvs' tenv.v|>) e t') ==>
      weakE (tenv_add_tvs tvs bindings) (tenv_add_tvs tvs' bindings'))))
==>
type_d extra_checks mn decls tenv (Dlet p e) empty_decls (FEMPTY, [], tenv_add_tvs tvs bindings))

/\ (! extra_checks mn tenv p e t bindings decls.
(
(* The following line makes sure that when the value restriction prohibits
   generalisation, a type error is given rather than picking an arbitrary
   instantiation. However, we should only do the check when the extra_checks
   argument tells us to. *)(extra_checks ==> (~ (is_value e) /\ type_pe_determ tenv p e)) /\
ALL_DISTINCT (pat_bindings p []) /\
type_p( 0) tenv.c p t bindings /\
type_e tenv e t)
==>
type_d extra_checks mn decls tenv (Dlet p e) empty_decls (FEMPTY, [], tenv_add_tvs( 0) bindings))

/\ (! extra_checks mn tenv funs bindings tvs decls.
(type_funs (tenv with<| v := bind_var_list( 0) bindings (bind_tvar tvs tenv.v)|>) funs bindings /\
(extra_checks ==>  
(! tvs' bindings'.
    type_funs (tenv with<| v := bind_var_list( 0) bindings' (bind_tvar tvs' tenv.v)|>) funs bindings' ==>
      weakE (tenv_add_tvs tvs bindings) (tenv_add_tvs tvs' bindings'))))
==>
type_d extra_checks mn decls tenv (Dletrec funs) empty_decls (FEMPTY, [], tenv_add_tvs tvs bindings))

/\ (! extra_checks mn tenv tdefs decls new_tdecls new_decls new_tenv_tabbrev.
(check_ctor_tenv mn (merge_mod_env (FEMPTY,new_tenv_tabbrev) tenv.t) tdefs /\
(new_tdecls = LIST_TO_SET (MAP (\ (tvs,tn,ctors) .  (mk_id mn tn)) tdefs)) /\
DISJOINT new_tdecls decls.defined_types /\
(new_tenv_tabbrev = FUPDATE_LIST FEMPTY (MAP (\ (tvs,tn,ctors) .  (tn, (tvs, Tapp (MAP Tvar tvs) (TC_name (mk_id mn tn))))) tdefs)) /\
(new_decls = <| defined_mods := {}; defined_types := new_tdecls; defined_exns := {} |>))
==>
type_d extra_checks mn decls tenv (Dtype tdefs) new_decls (new_tenv_tabbrev, build_ctor_tenv mn (merge_mod_env (FEMPTY,new_tenv_tabbrev) tenv.t) tdefs, []))

/\ (! extra_checks mn decls tenv tvs tn t.
(check_freevars( 0) tvs t /\
check_type_names tenv.t t /\
ALL_DISTINCT tvs)
==>
type_d extra_checks mn decls tenv (Dtabbrev tvs tn t) empty_decls (FEMPTY |+ (tn, (tvs,type_name_subst tenv.t t)), [], []))

/\ (! extra_checks mn tenv cn ts decls new_decls.
(check_exn_tenv mn cn ts /\
~ (mk_id mn cn IN decls.defined_exns) /\
EVERY (check_type_names tenv.t) ts /\
(new_decls = <| defined_mods := {}; defined_types := {}; defined_exns := {mk_id mn cn} |>))
==>
type_d extra_checks mn decls tenv (Dexn cn ts) new_decls (FEMPTY, [(cn, ([], MAP (type_name_subst tenv.t) ts, TypeExn (mk_id mn cn)))], []))`;

val _ = Hol_reln ` (! extra_checks mn tenv decls.
T
==>
type_ds extra_checks mn decls tenv [] empty_decls (FEMPTY, [], []))

/\ (! extra_checks mn tenv d ds new_tenv1 new_tenv2 decls decls' decls''.
(type_d extra_checks mn decls tenv d decls' new_tenv1 /\
type_ds extra_checks mn (union_decls decls' decls) (extend_env_new_decs new_tenv1 tenv) ds decls'' new_tenv2)
==>
type_ds extra_checks mn decls tenv (d::ds) (union_decls decls'' decls') (append_new_dec_tenv new_tenv2 new_tenv1))`;

val _ = Hol_reln ` (! mn tenv_tabbrev.
T
==>
type_specs mn tenv_tabbrev [] empty_decls (FEMPTY,[],[]))

/\ (! mn tenv_tabbrev x t specs new_tenv fvs decls.
(check_freevars( 0) fvs t /\
check_type_names tenv_tabbrev t /\
type_specs mn tenv_tabbrev specs decls new_tenv)
==>
type_specs mn tenv_tabbrev (Sval x t :: specs) decls
    (append_new_dec_tenv new_tenv (FEMPTY,[],[(x,(LENGTH fvs, type_subst (alist_to_fmap (ZIP (fvs, (MAP Tvar_db (GENLIST (\ x .  x) (LENGTH fvs)))))) (type_name_subst tenv_tabbrev t)))])))

/\ (! mn tenv_tabbrev new_tenv td specs new_tdecls new_decls decls new_tenv_tabbrev.
((new_tenv_tabbrev = FUPDATE_LIST FEMPTY (MAP (\ (tvs,tn,ctors) .  (tn, (tvs, Tapp (MAP Tvar tvs) (TC_name (mk_id mn tn))))) td)) /\
(new_tdecls = LIST_TO_SET (MAP (\ (tvs,tn,ctors) .  (mk_id mn tn)) td)) /\
check_ctor_tenv mn (merge_mod_env (FEMPTY,new_tenv_tabbrev) tenv_tabbrev) td /\
type_specs mn (merge_mod_env (FEMPTY,new_tenv_tabbrev) tenv_tabbrev) specs decls new_tenv /\
(new_decls = <| defined_mods := {}; defined_types := new_tdecls; defined_exns := {} |>))
==>
type_specs mn tenv_tabbrev (Stype td :: specs) (union_decls decls new_decls) (append_new_dec_tenv new_tenv (new_tenv_tabbrev, build_ctor_tenv mn (merge_mod_env (FEMPTY,new_tenv_tabbrev) tenv_tabbrev) td, [])))

/\ (! mn tenv_tabbrev tvs tn t specs decls new_tenv new_tenv_tabbrev.
(ALL_DISTINCT tvs /\
check_freevars( 0) tvs t /\
check_type_names tenv_tabbrev t /\
(new_tenv_tabbrev =FEMPTY |+ (tn, (tvs,type_name_subst tenv_tabbrev t))) /\
type_specs mn (merge_mod_env (FEMPTY,new_tenv_tabbrev) tenv_tabbrev) specs decls new_tenv)
==>
type_specs mn tenv_tabbrev (Stabbrev tvs tn t :: specs) decls (append_new_dec_tenv new_tenv (new_tenv_tabbrev, [], [])))

/\ (! mn tenv_tabbrev new_tenv cn ts specs decls new_decls.
(check_exn_tenv mn cn ts /\
type_specs mn tenv_tabbrev specs decls new_tenv /\
EVERY (check_type_names tenv_tabbrev) ts /\
(new_decls = <| defined_mods := {}; defined_types := {}; defined_exns := {mk_id mn cn} |>))
==>
type_specs mn tenv_tabbrev (Sexn cn ts :: specs) (union_decls decls new_decls) (append_new_dec_tenv new_tenv (FEMPTY, [(cn, ([], MAP (type_name_subst tenv_tabbrev) ts, TypeExn (mk_id mn cn)))], [])))

/\ (! mn tenv_tabbrev new_tenv tn specs tvs decls new_decls new_tenv_tabbrev.
(ALL_DISTINCT tvs /\
(new_tenv_tabbrev =FEMPTY |+ (tn, (tvs, Tapp (MAP Tvar tvs) (TC_name (mk_id mn tn))))) /\
type_specs mn (merge_mod_env (FEMPTY,new_tenv_tabbrev) tenv_tabbrev) specs decls new_tenv /\
(new_decls = <| defined_mods := {}; defined_types := {mk_id mn tn}; defined_exns := {} |>))
==>
type_specs mn tenv_tabbrev (Stype_opq tvs tn :: specs) (union_decls decls new_decls) (append_new_dec_tenv new_tenv (new_tenv_tabbrev, [], [])))`;

(*val flat_weakC : flat_tenv_ctor -> flat_tenv_ctor -> bool*)
val _ = Define `
 (flat_weakC cenv_impl cenv_spec =  
(! cn.
    (case ALOOKUP cenv_spec cn of
        SOME (tvs_spec,ts_spec,tn_spec) =>
          (case ALOOKUP cenv_impl cn of
              NONE => F
            | SOME (tvs_impl, ts_impl, tn_impl) =>                
(tn_spec = tn_impl) /\                
(
                (* For simplicity, we reject matches that differ only by renaming of bound type variables *)tvs_spec = tvs_impl) /\                
(ts_spec = ts_impl)
          )
      | NONE => T
    )))`;


(*val weak_decls : decls -> decls -> bool*)
val _ = Define `
 (weak_decls decls_impl decls_spec =
  ((decls_impl.defined_mods = decls_spec.defined_mods) /\  
(decls_spec.defined_types SUBSET decls_impl.defined_types) /\  
(decls_spec.defined_exns SUBSET decls_impl.defined_exns)))`;


(*val flat_weakT : maybe modN -> flat_tenv_tabbrev -> flat_tenv_tabbrev -> bool*)
val _ = Define `
 (flat_weakT mn tenv_tabbrev_impl tenv_tabbrev_spec =  
(! tn.
    (case FLOOKUP tenv_tabbrev_spec tn of
        SOME (tvs_spec, t_spec) =>
          (case FLOOKUP tenv_tabbrev_impl tn of
              NONE => F
            | SOME (tvs_impl, t_impl) =>                
(
                (* For simplicity, we reject matches that differ only by renaming of bound type variables *)tvs_spec = tvs_impl) /\
                ((t_spec = t_impl) \/                 
(
                 (* The specified type is opaque *)t_spec = Tapp (MAP Tvar tvs_spec) (TC_name (mk_id mn tn))))
          )
      | NONE => T
    )))`;


(*val weak_new_dec_tenv : maybe modN -> new_dec_tenv -> new_dec_tenv -> bool*)
val _ = Define `
 (weak_new_dec_tenv mn (t,c,v) (t',c',v') =  
(flat_weakT mn t t' /\
  flat_weakC c c' /\
  weakE v v'))`;


val _ = Hol_reln ` (! mn tenv_tabbrev decls new_tenv.
T
==>
check_signature mn tenv_tabbrev decls new_tenv NONE decls new_tenv)

/\ (! mn specs new_tenv1 new_tenv2 decls decls' tenv_tabbrev.
(weak_new_dec_tenv mn new_tenv1 new_tenv2 /\
weak_decls decls decls' /\
type_specs mn tenv_tabbrev specs decls' new_tenv2)
==>
check_signature mn tenv_tabbrev decls new_tenv1 (SOME specs) decls' new_tenv2)`;

(*val lift_new_dec_tenv : new_dec_tenv -> new_top_tenv*)
val _ = Define `
 (lift_new_dec_tenv (t,c,v) =
  ((FEMPTY,t), FEMPTY, ([],c), v))`;


(*val mod_lift_new_dec_tenv : modN -> new_dec_tenv -> new_top_tenv*)
val _ = Define `
 (mod_lift_new_dec_tenv mn (t,c,v) =
  ((FEMPTY |+ (mn, t), FEMPTY),FEMPTY |+ (mn, v), ([(mn,c)],[]), []))`;



val _ = Hol_reln ` (! extra_checks tenv d new_tenv decls decls'.
(type_d extra_checks NONE decls tenv d decls' new_tenv)
==>
type_top extra_checks decls tenv (Tdec d) decls' (lift_new_dec_tenv new_tenv))

/\ (! extra_checks tenv mn spec ds new_tenv1 new_tenv2 decls decls' decls'' new_decls.
(~ (mn IN decls.defined_mods) /\
type_ds extra_checks (SOME mn) decls tenv ds decls' new_tenv1 /\
check_signature (SOME mn) tenv.t decls' new_tenv1 spec decls'' new_tenv2 /\
(new_decls = <| defined_mods := {mn}; defined_types := {}; defined_exns := {} |>))
==>
type_top extra_checks decls tenv (Tmod mn spec ds) (union_decls new_decls decls'') (mod_lift_new_dec_tenv mn new_tenv2))`;

val _ = Hol_reln ` (! extra_checks tenv decls.
T
==>
type_prog extra_checks decls tenv [] empty_decls ((FEMPTY,FEMPTY), FEMPTY, ([],[]), []))

/\ (! extra_checks tenv top tops new_tenv1 new_tenv2 decls decls' decls''.
(type_top extra_checks decls tenv top decls' new_tenv1 /\
type_prog extra_checks (union_decls decls' decls) (extend_env_new_tops new_tenv1 tenv) tops decls'' new_tenv2)
==>
type_prog extra_checks decls tenv (top :: tops) (union_decls decls'' decls') (append_new_top_tenv new_tenv2 new_tenv1))`;
val _ = export_theory()

