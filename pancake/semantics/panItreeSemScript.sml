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
enable_monadsyntax();
declare_monad("itree", {unit = “Ret”, bind = “itree_bind”,
              ignorebind = NONE,
              choice = NONE,
              fail = NONE,
              guard = NONE});
enable_monad "itree";

(* Unicode overloads *)
val _ = temp_set_fixity "≈" (Infixl 500);
Overload "≈" = “itree_wbisim”;
Overload "case" = “itree_CASE”;

Datatype:
  sem_vis_event = FFI_call string (word8 list) (word8 list)
End

val s = “s:('a,'b) state”;
val s1 = “s1:('a,'b) state”;
val p1 = “p1:'a panLang$prog”;
val p2 = “p2:'a panLang$prog”;

(* TODO: Call this mtree_ret *)
Type mtree_ans[pp] = “:'a result option # ('a,'b) state”;
Type htree_seed[pp] = “:'a panLang$prog # ('a,'b) state”;
Type semtree_ans[pp] = “:'b ffi_result”;

(* Continuation for mtrees: these are nested inside the ITree event type of
mtree's and htree's. *)
Type mtree_cont[pp] = “:'b ffi_result -> ('a,'b) mtree_ans”;
Type mtree_event[pp] = “:sem_vis_event # ('a,'b) mtree_cont”;

Type htree[pp] = “:(('a,'b) mtree_ans,
                    ('a,'b) htree_seed + ('a,'b) mtree_event,
                    ('a,'b) mtree_ans) itree”;
Type hktree[pp] = “:('a,'b) mtree_ans -> ('a,'b) htree”;

Type mtree[pp] = “:(('a,'b) mtree_ans,
                    ('a,'b) mtree_event,
                    ('a,'b) mtree_ans) itree”;
Type mktree[pp] = “:('a,'b) mtree_ans -> ('a,'b) mtree”;

Type semtree[pp] = “:('b ffi_result, sem_vis_event, 'a result option) itree”;
Type sem8tree[pp] = “:('b ffi_result, sem_vis_event, 8 result option) itree”;
Type sem16tree[pp] = “:('b ffi_result, sem_vis_event, 16 result option) itree”;

Definition mrec_iter_body_def:
  mrec_iter_body rh t =
  case t of
   | Ret r => Ret (INR r)
   | Tau t => Ret (INL t)
   | Vis (INL seed') k => Ret (INL (itree_bind (rh seed') k))
   | Vis (INR e) k => Vis e (Ret o INL o k)
End

Definition mrec_body_def:
  mrec_body rh = itree_iter $ mrec_iter_body rh
End

Definition itree_mrec_def:
  itree_mrec rh seed = mrec_body rh (rh seed)
End

(* mrec theory *)

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
  h_prog_rule_seq ^p1 ^p2 ^s = Vis (INL (p1,s))
                                (λ(res,s'). if res = NONE
                                            then Vis (INL (p2,s')) Ret
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
                               (λ(p,s). case (eval s g) of
                                        | SOME (ValWord w) =>
                                           if (w ≠ 0w)
                                           then (Vis (INL (p,s))
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
                                                  NONE => Ret (SOME (Return retv),empty_locals s')
                                                 | SOME (rt,_) =>
                                                    if is_valid_value s.locals rt retv
                                                    then Ret (NONE,set_var rt retv (s' with locals := s.locals))
                                                    else Ret (SOME Error,s')) ∧
  (h_handle_call_ret calltyp s (SOME (Exception eid exn),s') = case calltyp of
                                                        NONE => Ret (SOME (Exception eid exn),empty_locals s')
                                                       | SOME (_,NONE) => Ret (SOME (Exception eid exn),empty_locals s')
                                                       | SOME (_,(SOME (eid', evar, p))) =>
                                                          if eid = eid'
                                                          then
                                                            (case FLOOKUP s.eshapes eid of
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
           Vis (INL (callee_prog,s with locals := newlocals)) (h_handle_call_ret calltyp s)
        | _ => Ret (SOME Error,s))
   | (_,_) => Ret (SOME Error,s)
End

Definition h_prog_rule_ext_call_def:
  h_prog_rule_ext_call ffi_name conf_ptr conf_len array_ptr array_len ^s =
  case (eval s conf_ptr,eval s conf_len,eval s array_ptr,eval s array_len) of
    (SOME (ValWord conf_ptr_adr),SOME (ValWord conf_sz),
     SOME (ValWord array_ptr_adr),SOME (ValWord array_sz)) =>
     (case (read_bytearray conf_ptr_adr (w2n conf_sz) (mem_load_byte s.memory s.memaddrs s.be),
            read_bytearray array_ptr_adr (w2n array_sz) (mem_load_byte s.memory s.memaddrs s.be)) of
        (SOME conf_bytes,SOME array_bytes) =>
         Vis (INR (FFI_call (explode ffi_name) conf_bytes array_bytes,
                   (λres. case res of
                            FFI_final outcome => (SOME (FinalFFI outcome),empty_locals s):('a result option # ('a,'b) state)
                           | FFI_return new_ffi new_bytes =>
                              let nmem = write_bytearray array_ptr_adr new_bytes s.memory s.memaddrs s.be in
                              (NONE,s with <| memory := nmem; ffi := new_ffi |>)))) Ret
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

(* Converts an mtree into a semtree *)
Definition sem_outer_def:
  sem_outer =
  itree_unfold
  (λt. case t of
         Ret (res,s) => Ret' res
        | Tau t => Tau' t
        | Vis (e,k) g => Vis' e (g o k))
End

(* ITree semantics for program commands *)
Definition itree_evaluate_def:
  itree_evaluate p s =
  sem_outer (itree_mrec h_prog (p,s))
End

(* Observational ITree semantics *)
val s = ``(s:('a,'ffi) panSem$state)``;

Definition itree_semantics_def:
  itree_semantics ^s entry =
  let prog = Call NONE (Label entry) [] in
  (itree_evaluate prog ^s)
End

Definition mrec_sem_def:
  mrec_sem (seed:(('a,'b) htree)) = mrec_body h_prog seed
End

Triviality mrec_iter_body_eq:
  mrec_iter_body h_prog = (λt. case t of
                                       Ret r => Ret (INR r)
                                      | Tau t => Ret (INL t)
                                      | Vis (INL seed') k => Ret (INL (monad_bind (h_prog seed') k))
                                      | Vis (INR e) k => Vis e (Ret ∘ INL ∘ k))
Proof
  rw [FUN_EQ_THM] >>
  rw [mrec_iter_body_def]
QED

Theorem mrec_handler_simps[simp]:
  (itree_mrec h_prog (Skip,s) = Ret (NONE,s)) ∧
  (itree_mrec h_prog (Dec vname e p,s) = mrec_sem $ h_prog_rule_dec vname e p s) ∧
  (itree_mrec h_prog (Assign vname e,s) = mrec_sem $ h_prog_rule_assign vname e s) ∧
  (itree_mrec h_prog (Store dst src,s) = mrec_sem $ h_prog_rule_store dst src s) ∧
  (itree_mrec h_prog (StoreByte dst src,s) = mrec_sem $ h_prog_rule_store_byte dst src s) ∧
  (itree_mrec h_prog (Seq p1 p2,s) = mrec_sem $ h_prog_rule_seq p1 p2 s) ∧
  (itree_mrec h_prog (If gexp p1 p2,s) = mrec_sem $ h_prog_rule_cond gexp p1 p2 s) ∧
  (itree_mrec h_prog (While gexp p,s) = mrec_sem $ h_prog_rule_while gexp p s) ∧
  (itree_mrec h_prog (Break,s) = Ret (SOME Break,s)) ∧
  (itree_mrec h_prog (Continue,s) = Ret (SOME Continue,s)) ∧
  (itree_mrec h_prog (Call calltyp tgtexp argexps,s) = mrec_sem $ h_prog_rule_call calltyp tgtexp argexps s) ∧
  (itree_mrec h_prog (ExtCall ffi_name conf_ptr conf_len array_ptr array_len,s) =
   mrec_sem $ h_prog_rule_ext_call ffi_name conf_ptr conf_len array_ptr array_len s) ∧
  (itree_mrec h_prog (Raise eid e,s) = mrec_sem $ h_prog_rule_raise eid e s) ∧
  (itree_mrec h_prog (Return e,s) = mrec_sem $ h_prog_rule_return e s) ∧
  (itree_mrec h_prog (Tick,s) = mrec_sem $ h_prog_rule_tick s)
Proof
  rpt strip_tac >>
  rw [itree_mrec_def,h_prog_def,mrec_sem_def] >>
  rw [mrec_body_def,mrec_iter_body_eq] >>
  rw [itreeTauTheory.itree_iter_def] >>
  rw [Once itreeTauTheory.itree_unfold]
QED

(*
  do
    x <- (Ret (INL (itree_bind (h_prog seed) k)));
    case x of
      INL a => Tau (itree_iter (mrec_iter_body h_prog) a)
     | INR b => Ret b
  od
*)

Theorem mrec_sem_simps[simp]:
  mrec_sem (Vis (INL seed) k) =
  Tau (mrec_sem (itree_bind (h_prog seed) k))
Proof
  rw [mrec_sem_def,mrec_body_def,mrec_iter_body_eq] >>
  rw [Once itreeTauTheory.itree_iter_thm]
QED

val _ = export_theory();
