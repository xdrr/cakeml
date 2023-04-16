(*
    An itree semantics for Pancake.
*)

open preamble panLangTheory;
local open alignmentTheory
           miscTheory     (* for read_bytearray *)
           wordLangTheory (* for word_op and word_sh *)
           ffiTheory
           itreeTauTheory
           panSemTheory in end;

val _ = new_theory "panItreeSem";

(* Extension of itreeTauTheory *)
val _ = temp_set_fixity "\226\139\134" (Infixl 500);
Overload "\226\139\134" = “itree_bind”;

val _ = temp_set_fixity "≈" (Infixl 500);
Overload "≈" = “itree_wbisim”;

Definition itree_trigger_def:
  itree_trigger event = Vis event Ret
End

Definition itree_mrec_def:
  itree_mrec rh seed =
  itree_iter
  (λt. case t of
        | Ret r => Ret (INR r)
        | Tau t => Ret (INL t)
        | Vis (INL seed') k => Ret (INL (itree_bind (rh seed') k))
        | Vis (INR e) k => Vis e (λx. Ret (INL (k x))))
  (rh seed)
End

Theorem itree_mrec_simps2[simp]:
  ((rh seed) = Ret r ⇒ itree_mrec rh seed = Ret r)
Proof
  rw [itree_mrec_def] >>
  rw [itreeTauTheory.itree_iter_def] >>
  rw [Once itreeTauTheory.itree_unfold]
QED

Theorem itree_mrec_simps[simp]:
  (itree_mrec Ret s = Ret s)
Proof
  rw [itree_mrec_def] >>
  rw [itreeTauTheory.itree_iter_def] >>
  rw [Once itreeTauTheory.itree_unfold]
QED

Theorem itree_mrec_recurse_once[simp]:
  (h s) = Vis (INL seed') k ⇔
  itree_mrec h s = Tau (itree_mrec (λs. itree_bind (h s) k) seed')
Proof
  rw [itree_mrec_def] >>
  rw [itreeTauTheory.itree_iter_def] >>
  rw [Once itreeTauTheory.itree_unfold] >>
  (* needs proof that k' = k and then itree_bind_right_identity *)
  cheat
QED

(* mrec theory *)

(* Show that mrec Vis (INL) nodes are equivalent to one step of general recursion *)
Definition simple_rec_def:
  (simple_rec (0:num) = 0) ∧
  (simple_rec (SUC a) = 1 + (simple_rec a))
End

Theorem itree_mrec_one_rec_event:
  itree_mrec
  (λseed. if seed = 0 then Vis (INL 1) Ret else Ret seed)
  0 = Tau (Ret 1)
Proof
  rw [itree_mrec_def] >>
  rw [itreeTauTheory.itree_iter_def,itreeTauTheory.itree_bind_def] >>
  rpt (rw [Once itreeTauTheory.itree_unfold])
QED

(* Two approaches to reasoning about ITrees as processes:
  - As an equational theory over the itree datatype (the abstraction).
  - As a function on finite paths to :itree_el terms (the representation).

  Each may have their own merits.
 *)

(* Characterisation of infinite itree:s in terms of their paths. *)
Definition itree_finite_def:
  itree_finite t = ∃p x. itree_el t p = Return x
End

Definition itree_infinite_def:
  itree_infinite t = ¬(itree_finite t)
End

(* Simp rules for characteristics predicates of
 ITrees *)
Theorem itree_char_simps[simp,compute]:
  (∀r. ¬(itree_infinite $ Ret r))
Proof
  rw [itree_infinite_def,itree_finite_def] >>
  qexists_tac ‘[]’  >>
  qexists_tac ‘r’ >>
  rw [itreeTauTheory.itree_el_def]
QED

(* To prove an ITree is infinite, it suffices to show there is no sequence of events
 after which the tree returns some value. *)
Theorem itree_mrec_inf_event:
  itree_infinite (itree_mrec (λx. Vis (INL rc) Ret) seed)
Proof
  rw [itree_infinite_def,itree_finite_def] >>
  rw [itree_mrec_def]  >>
  rw [itreeTauTheory.itree_iter_def,
        itreeTauTheory.itree_bind_right_identity] >>
  Induct_on ‘p’ >>
  rw [Once itreeTauTheory.itree_unfold,
      itreeTauTheory.itree_bind_right_identity] >>
  Cases_on ‘h’ >>
  rw [itreeTauTheory.itree_el_def]
QED

(* Semantics validation functions *)
(* The rules for the recursive event handler, that decide
 how to evaluate each term of the program command grammar. *)

Definition h_prog_rule_dec_def:
  h_prog_rule_dec vname e p s =
  case (eval s e) of
   | SOME value => Vis (INL (p,s with locals := s.locals |+ (vname,value)))
                       (λ(res,s'). Ret (res,s' with locals := res_var s'.locals (vname, FLOOKUP s.locals vname)))
   | NONE => Ret (SOME Error,s)
End

Definition h_prog_rule_seq_def:
  h_prog_rule_seq p1 p2 s = Vis (INL (p1,s))
                                (λ(res,s'). if res = NONE
                                            then itree_trigger (INL (p2,s'))
                                            else Ret (res,s'))
End

Definition h_prog_rule_assign_def:
  h_prog_rule_assign vname e s =
  case (eval s e) of
   | SOME value =>
      if is_valid_value s.locals vname value
      then Ret (NONE,s with locals := s.locals |+ (vname,value))
      else Ret (SOME Error,s)
   | NONE => Ret (SOME Error,s)
End

Definition h_prog_rule_store_def:
  h_prog_rule_store dst src s =
  case (eval s dst,eval s src) of
   | (SOME (ValWord addr),SOME value) =>
      (case mem_stores addr (flatten value) s.memaddrs s.memory of
        | SOME m => Ret (NONE,s with memory := m)
        | NONE => Ret (SOME Error,s))
   | _ => Ret (SOME Error,s)
End

Definition h_prog_rule_store_byte_def:
  h_prog_rule_store_byte dst src s =
  case (eval s dst,eval s src) of
   | (SOME (ValWord addr),SOME (ValWord w)) =>
      (case mem_store_byte s.memory s.memaddrs s.be addr (w2w w) of
        | SOME m => Ret (NONE,s with memory := m)
        | NONE => Ret (SOME Error,s))
   | _ => Ret (SOME Error,s)
End

Definition h_prog_rule_cond_def:
  h_prog_rule_cond gexp p1 p2 s =
  case (eval s gexp) of
   | SOME (ValWord g) => Vis (INL (if g ≠ 0w then p1 else p2,s)) Ret
   | _ => Ret (SOME Error,s)
End

(* NB The design of this while denotation restricts the type of Vis at this level of the semantics
 to having k-trees of: (res,state) -> (a,b,c) itree. *)
(* This is converted to the desired state in the top-level semantics. *)

(* Inf ITree of Vis nodes, with inf many branches allowing
 termination of the loop; when the guard is false. *)
Definition h_prog_rule_while_def:
  h_prog_rule_while g p s = itree_iter
                               (λseed. case (eval s g) of
                                        | SOME (ValWord w) =>
                                           if (w ≠ 0w)
                                           then (Vis (INL seed)
                                                 (λ(res,s'). case res of
                                                              | SOME Break => Ret (INR (NONE,s'))
                                                              | SOME Continue => Ret (INL (p,s'))
                                                              | NONE => Ret (INL (p,s'))
                                                              | _ => Ret (INR (res,s'))))
                                           else Ret (INR (NONE,s))
                                        | _ => Ret (INR (SOME Error,s)))
                               (p,s)
End

(* Handles the return value and exception passing of function calls. *)
Definition h_handle_call_ret_def:
  (h_handle_call_ret calltyp s (NONE,s') = Ret (SOME Error,s')) ∧
  (h_handle_call_ret calltyp s (SOME Break,s') = Ret (SOME Error,s')) ∧
  (h_handle_call_ret calltyp s (SOME Continue,s') = Ret (SOME Error,s')) ∧
  (h_handle_call_ret calltyp s (SOME (Return retv),s') = case calltyp of
                                                  Tail => Ret (SOME (Return retv),empty_locals s')
                                                 | Ret dvar _ =>
                                                    if is_valid_value s.locals dvar retv
                                                    then Ret (NONE,set_var dvar retv (s' with locals := s.locals))
                                                    else Ret (SOME Error,s')) ∧
  (h_handle_call_ret calltyp s (SOME (Exception eid exn),s') = case calltyp of
                                                       | Tail => Ret (SOME (Exception eid exn),empty_locals s')
                                                       | Ret _ NONE => Ret (SOME (Exception eid exn),empty_locals s')
                                                       | Ret _ (SOME (Handle eid' evar p)) =>
                                                          if eid = eid'
                                                          then (case FLOOKUP s.eshapes eid of
                                                                  SOME sh =>
                                                                   if shape_of exn = sh ∧ is_valid_value s.locals evar exn
                                                                   then Vis (INL (p,set_var evar exn (s' with locals := s.locals))) Ret
                                                                   else Ret (SOME Error,s')
                                                                 | NONE => Ret (SOME Error,s'))
                                                          else Ret (SOME (Exception eid exn),empty_locals s')) ∧
  (h_handle_call_ret calltyp s (res,s') = Ret (res,empty_locals s'))
End

Definition h_prog_rule_call_def:
  h_prog_rule_call calltyp tgtexp argexps s =
  case (eval s tgtexp,OPT_MMAP (eval s) argexps) of
   | (SOME (ValLabel fname),SOME args) =>
      (case lookup_code s.code fname args of
        | SOME (callee_prog,newlocals) =>
           Vis (INL (callee_prog,s)) (h_handle_call_ret calltyp s)
        | _ => Ret (SOME Error,s))
   | (_,_) => Ret (SOME Error,s)
End

(* The type of visible events in the ITree semantics. *)
Type ktree = “:α -> (α,β,γ) itree”

Datatype:
  sem_vis_event = FFI_call ('ffi ffi_state) string (word8 list) (word8 list)
End

Definition h_prog_rule_ext_call_def:
  h_prog_rule_ext_call ffi_name conf_ptr conf_len array_ptr array_len s =
  case (FLOOKUP s.locals conf_len,FLOOKUP s.locals conf_ptr,FLOOKUP s.locals array_len,FLOOKUP s.locals array_ptr) of
    (SOME (ValWord conf_sz),SOME (ValWord conf_ptr_adr),
           SOME (ValWord array_sz),SOME (ValWord array_ptr_adr)) =>
                                    (case (read_bytearray conf_ptr_adr (w2n conf_sz) (mem_load_byte s.memory s.memaddrs s.be),
                                           read_bytearray array_ptr_adr (w2n array_sz) (mem_load_byte s.memory s.memaddrs s.be)) of
                                       (SOME conf_bytes,SOME array_bytes) =>
                                        Vis (INR (FFI_call s.ffi (explode ffi_name) conf_bytes array_bytes,
                                            (λres. case res of
                                                     FFI_final outcome => Ret (SOME (FinalFFI outcome),empty_locals s)
                                                    | FFI_return new_ffi new_bytes =>
                                                       let nmem = write_bytearray array_ptr_adr new_bytes s.memory s.memaddrs s.be in
                                                       Ret (NONE,s with <| memory := nmem; ffi := new_ffi |>)
                                                       | _ => Ret (SOME Error,s))))
                                            (λx. case call_FFI s.ffi (explode ffi_name) conf_bytes array_bytes of
                                                   FFI_final outcome => Ret (SOME (FinalFFI outcome),empty_locals s)
                                                  | FFI_return new_ffi new_bytes =>
                                                     let nmem = write_bytearray array_ptr_adr new_bytes s.memory s.memaddrs s.be in
                                                     Ret (NONE,s with <| memory := nmem; ffi := new_ffi |>))
                                      | _ => Ret (SOME Error,s))
   | _ => Ret (SOME Error,s)
End

Definition h_prog_rule_raise_def:
  h_prog_rule_raise eid e s =
  case (FLOOKUP s.eshapes eid, eval s e) of
   | (SOME sh, SOME value) =>
      if shape_of value = sh ∧
         size_of_shape (shape_of value) <= 32
      then Ret (SOME (Exception eid value),empty_locals s)
      else Ret (SOME Error,s)
   | _ => Ret (SOME Error,s)
End

Definition h_prog_rule_return_def:
  h_prog_rule_return e s =
  case (eval s e) of
   | SOME value =>
      if size_of_shape (shape_of value) <= 32
      then Ret (SOME (Return value),empty_locals s)
      else Ret (SOME Error,s)
   | _ => Ret (SOME Error,s)
End

Definition h_prog_rule_tick_def:
  h_prog_rule_tick s =
  case s.clock of
    0 => Ret (SOME TimeOut,empty_locals s)
   | _ => Ret (NONE,dec_clock s)
End

(* Recursive event handler for program commands *)
Definition h_prog_def:
  (h_prog (Skip,s) = Ret (NONE,s)) ∧
  (h_prog (Dec vname e p,s) = h_prog_rule_dec vname e p s) ∧
  (h_prog (Assign vname e,s) = h_prog_rule_assign vname e s) ∧
  (h_prog (Store dst src,s) = h_prog_rule_store dst src s) ∧
  (h_prog (StoreByte dst src,s) = h_prog_rule_store_byte dst src s) ∧
  (h_prog (Seq p1 p2,s) = h_prog_rule_seq p1 p2 s) ∧
  (h_prog (If gexp p1 p2,s) = h_prog_rule_cond gexp p1 p2 s) ∧
  (h_prog (While gexp p,s) = h_prog_rule_while gexp p s) ∧
  (h_prog (Break,s) = Ret (SOME Break,s)) ∧
  (h_prog (Continue,s) = Ret (SOME Continue,s)) ∧
  (h_prog (Call calltyp tgtexp argexps,s) = h_prog_rule_call calltyp tgtexp argexps s) ∧
  (h_prog (ExtCall ffi_name conf_ptr conf_len array_ptr array_len,s) =
          h_prog_rule_ext_call ffi_name conf_ptr conf_len array_ptr array_len s) ∧
  (h_prog (Raise eid e,s) = h_prog_rule_raise eid e s) ∧
  (h_prog (Return e,s) = h_prog_rule_return e s) ∧
  (h_prog (Tick,s) = h_prog_rule_tick s)
End

(* ITree semantics for program commands *)
Definition evaluate_itree_def:
  evaluate_itree p s = itree_mrec h_prog (p,s)
End

(* Observational ITree semantics *)

val s = ``(s:('a,'ffi) panSem$state)``;

Definition semantics_itree_def:
  semantics_itree ^s entry =
  let prog = Call Tail (Label entry) [] in
  itree_unfold
  (λt. case t of
         INL (Ret (res,s)) => Ret' res
        | INL (Tau t) => Tau' (INL t)
        | INL (Vis (e,k) g) => Vis' e (λr. INR (k r))
        | INR (Ret (res,s)) => Ret' res
        | INR (Tau t) => Tau' (INR t)
        | INR (Vis e g) => Vis' e (INR o g))
  (INL (evaluate_itree prog ^s))
End

val _ = export_theory();