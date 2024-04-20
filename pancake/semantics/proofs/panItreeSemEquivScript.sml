(*
    Proof of correspondence between functional big-step
    and itree semantics for Pancake.
*)

open preamble panLangTheory;
local open alignmentTheory
           miscTheory     (* for read_bytearray *)
           wordLangTheory (* for word_op and word_sh *)
           ffiTheory
           itreeTauTheory
           panSemTheory
           panPropsTheory
           panItreeSemTheory in end;

val _ = new_theory "panItreeSemEquiv";

val _ = temp_set_fixity "≈" (Infixl 500);
Overload "≈" = “itree_wbisim”;
val _ = temp_set_fixity ">>=" (Infixl 500);
Overload ">>=" = “itree_bind”;
Overload "case" = “itree_CASE”;

Definition query_oracle_def[nocompute]:
  query_oracle ffis (FFI_call s conf bytes) =
  case call_FFI ffis s conf bytes of
    FFI_return ffis' bytes' => (FFI_return ffis' bytes',bytes',ffis')
  | FFI_final (Final_event name conf' bytes' outcome) =>
              (FFI_final (Final_event name conf' bytes' outcome),bytes',ffis)
End

Definition make_io_event_def[nocompute]:
  make_io_event (FFI_call s conf bytes) rbytes =
                IO_event s conf (ZIP (bytes,rbytes))
End

(* Path over semtrees:
 - states consist of (ffi_state x 'a result option) pairs,
 - transition labels have type: 'b sem_vis_event option
 *)
val t = “t:('a,'b,'c) itree”;

Definition semtree_path_def:
  semtree_path f s ^t =
  unfold (λ(t,s1). case t of
                     Ret r => (s1,SOME r)
                   | Tau u => (s1,NONE)
                   | Vis e k => let (a,s1') = (f s1 e) in (s1',NONE))
         (λ(t,s1). case t of
                     Ret r => NONE
                   | Tau u => SOME ((u,s1),NONE)
                   | Vis e k => let (a,s1') = (f s1 e) in
                                    SOME ((k a,s1'),SOME e))
         (t,s)
End

(* Produces a llist of the IO events on a path in the given tree
 determined by a stateful branching choice function. *)
val st = “st:('a,'b) stree”;

Definition stree_trace_def:
  stree_trace f fs ^st =
  LFLATTEN $ LUNFOLD
  (λ(fs',t). case t of
                 Ret r => NONE
               | Tau u => SOME ((fs',u),LNIL)
               | Vis e k => let (a,rbytes,fs'') = f fs' e in
                                SOME ((fs'',k a),[|make_io_event e rbytes|]))
  (fs,st)
End

Theorem itree_bind_ret_inv:
  itree_bind t k = Ret x ⇒ ∃r. (k r) = Ret x
Proof
  disch_tac >>
  Cases_on ‘t’ >>
  fs [itreeTauTheory.itree_bind_thm] >>
  metis_tac []
QED

Theorem itree_bind_ret_tree:
  itree_bind t k = Ret x ⇒
  ∃y. t = Ret y
Proof
  disch_tac >>
  Cases_on ‘t’
  >- (metis_tac [itreeTauTheory.itree_bind_thm]) >>
  fs [itreeTauTheory.itree_bind_def]
QED

Theorem itree_bind_ret_inv_gen:
  itree_bind t k = Ret x ⇒
  ∃y. t = Ret y ∧ (k y) = Ret x
Proof
  disch_tac >>
  Cases_on ‘t’
  >- (qexists_tac ‘x'’ >> rw [] >>
      fs [itreeTauTheory.itree_bind_thm]) >>
  fs [itreeTauTheory.itree_bind_def]
QED

Theorem fbs_eval_clock_and_ffi_eq:
  ∀s e k ffis.
       eval s e = eval (s with <| clock := k; ffi := ffis |>) e
Proof
  recInduct panSemTheory.eval_ind >>
  rw [panSemTheory.eval_def] >>
  metis_tac [OPT_MMAP_cong]
QED

Theorem fbs_eval_clock_eq:
  ∀s e k.
  eval (s with clock := k) e = eval s e
Proof
  recInduct panSemTheory.eval_ind >>
  rw [panSemTheory.eval_def] >>
  metis_tac [OPT_MMAP_cong]
QED

Theorem opt_mmap_eval_clock_ffi_eq:
  ∀s e k ffis.
       OPT_MMAP (eval s) e = OPT_MMAP (eval (s with <| clock := k; ffi := ffis |>)) e
Proof
  rw [] >>
  ho_match_mp_tac OPT_MMAP_cong >>
  rw [fbs_eval_clock_and_ffi_eq]
QED


(*

ltree is the monad of leaves of an mtree (essentially branches that contain only
Ret and Tau nodes).

ltree_lift lifts the mtree monad into the ltree monad and satisfies the usual
monad transformer laws.

*)

Definition ltree_lift_def:
  (ltree_lift f st (mt:('a,'b) mtree)):('a,'b) ltree =
  itree_iter
  (λ(t,st). case t of
        Ret x => Ret (INR x)
       | Tau u => Ret (INL (u,st))
       | Vis (e,k) g => let (a,rbytes,st') = (f st e) in
                            Ret (INL ((g o k) a,st')))
  (mt,st)
End

Definition ltree_converges_def:
  ltree_converges lt ⇔ ∃r. lt ≈ Ret r
End

Definition ltree_diverges_def:
  ltree_diverges lt ⇔ ¬(ltree_converges lt)
End

Theorem ltree_lift_cases:
  (ltree_lift f st (Ret x) = Ret x) ∧
  (ltree_lift f st (Tau u) = Tau (ltree_lift f st u)) ∧
  (ltree_lift f st (Vis (e,k) g) = let (a,rbytes,st') = (f st e) in
                                   Tau (ltree_lift f st' ((g o k) a)))
Proof
  rpt strip_tac >>
  rw [ltree_lift_def] >>>
     LASTGOAL (Cases_on ‘f st e’ >> Cases_on ‘r’) >>>
     ALLGOALS (rw [Once itreeTauTheory.itree_iter_thm])
QED

Theorem itree_bind_left_ident_over_f:
  f $ Ret x >>= k = f (k x)
Proof
  AP_TERM_TAC >>
  rw [itreeTauTheory.itree_bind_thm]
QED

Theorem itree_eq_imp_wbisim:
  t = t' ⇒ t ≈ t'
Proof
  rw [Once itreeTauTheory.itree_wbisim_strong_coind] >>
  rw [itreeTauTheory.itree_wbisim_refl]
QED

Theorem itree_bind_left_ident_wbisim:
  Ret r >>= k ≈ k r
Proof
  rw [itree_eq_imp_wbisim]
QED

Theorem itree_bind_thm_wbisim:
  t ≈ Ret r ⇒ t >>= k ≈ k r
Proof
  disch_tac >>
  drule itreeTauTheory.itree_bind_resp_t_wbisim >>
  rw [itree_bind_left_ident_wbisim]
QED
(*
(* TODO: Finish this *)
Theorem msem_ret_wbisim_eq:
  mrec_sem ht ≈ Ret x ⇒
  ht ≈ Ret x
Proof
  fs [panItreeSemTheory.mrec_sem_def] >>
  namedCases_on ‘ht’ ["x","x","x"] >>
  cheat
QED

Theorem itree_wbisim_ret_u:
  Ret x ≈ u ⇒
  u = Ret x
Proof
  cheat
QED

Theorem itree_wbisim_vis_ret:
  Ret x ≈ Vis e k ⇒ F
Proof
  rw [Once itreeTauTheory.itree_wbisim_cases]
QED

Theorem msem_strip_tau:
  (strip_tau ht (Ret x) ⇒
   mrec_sem ht = mrec_sem (Ret x)) ∧
  (strip_tau ht (Vis (INL seed) k) ⇒
   mrec_sem ht = Tau (case ht of
                   Tau u => mrec_sem u
                      | _ => mrec_sem ht)) ∧
  (strip_tau ht (Vis (INR e) k) ⇒
   mrec_sem ht = (case ht of
                    Tau u => mrec_sem u
                    | _ => mrec_sem ht)) ∧
  (strip_tau ht (Tau u) ⇒
   mrec_sem ht = mrec_sem u)
Proof
  cheat
QED

Theorem strip_tau_vis_wbisim:
  ∀e k k'. strip_tau t (Vis e k) ∧ strip_tau t' (Vis e k') ∧ (∀r. k r ≈ k' r) ⇒
  t ≈ t'
Proof
  cheat
QED

Theorem msem_bind_left_ident:
  mrec_sem ht ≈ Ret x ⇒
  mrec_sem (ht >>= k) ≈ mrec_sem (k x)
Proof
  cheat
  (* disch_tac >> *)
  (* irule msem_resp_wbisim >> *)
  (* drule msem_ret_wbisim_eq >> *)
  (* disch_tac >> *)
  (* rw [itree_bind_thm_wbisim] *)
QED

(* corollary of ltree left ident law specialised to mrec_sem *)
Theorem msem_compos:
  mrec_sem (h_prog seed) ≈ Ret x ⇒
  mrec_sem (Vis (INL seed) k) ≈ mrec_sem (k x)
Proof
  disch_tac >>
  rw [panItreeSemTheory.mrec_sem_simps] >>
  rw [msem_bind_left_ident]
QED

(* TODO: Only the two theorems below need be proved to complete the
 correspondence proof at the level of wbisim equivalence for ltree's, i.e. by
 converting itree's into branches (still an ITree type) and showing equivalence
 with FBS semantics.

 NB Part of the work for ltree_lift_msem_resp_wbisim is already complete in
 msem_resp_wbisim.
 *)
Theorem ltree_lift_msem_resp_wbisim:
  ht ≈ ht' ⇒
  ltree_lift f st (mrec_sem ht) ≈ ltree_lift f st (mrec_sem ht')
Proof
  cheat
QED

val g = “g:('a,'b) mtree_ans -> ('a,'b) ltree”;

Theorem itree_wbisim_bind_trans:
  t1 ≈ t2 ∧ t1 >>= k ≈ t3 ⇒
  t2 >>= k ≈ t3
Proof
  strip_tac >>
  irule itreeTauTheory.itree_wbisim_trans >>
  qexists_tac ‘t1 >>= k’ >>
  strip_tac
  >- (irule itreeTauTheory.itree_bind_resp_t_wbisim >>
      rw [itreeTauTheory.itree_wbisim_sym])
  >- (rw [])
QED

Theorem itree_wbisim_bind_conv:
  ltree_lift f st (mrec_sem ht) ≈ Ret x ⇒
  (ltree_lift f st (mrec_sem ht) >>= ^g) ≈ g x
Proof
  disch_tac >>
  ‘ltree_lift f st (mrec_sem ht) ≈ ltree_lift f st (mrec_sem ht)’
    by (rw [itreeTauTheory.itree_wbisim_refl]) >>
  irule itree_wbisim_bind_trans >>
  qexists_tac ‘Ret x’ >>
  strip_tac
  >- (rw [itreeTauTheory.itree_wbisim_sym])
  >- (rw [itree_bind_thm_wbisim,
            itreeTauTheory.itree_wbisim_refl])
QED

Theorem msem_cases_tau:
  mrec_sem ht = Tau u ⇒
  (∃seed k. ht = Vis (INL seed) k) ∨
  (∃v. ht = Tau v)
Proof
  cheat
QED

Theorem msem_lift_monad_law:
  mrec_sem (ht >>= k) =
  (mrec_sem ht) >>= mrec_sem o k
Proof
  cheat
QED

Theorem ltree_lift_monad_law:
  ltree_lift f st (mt >>= k) =
  (ltree_lift f st mt) >>= (ltree_lift f st) o k
Proof
  cheat
QED

Theorem ltree_lift_bind_left_ident:
  (ltree_lift f st (mrec_sem ht)) ≈ Ret x ⇒
  (ltree_lift f st (mrec_sem (ht >>= k))) ≈ (ltree_lift f st (mrec_sem (k x)))
Proof
  disch_tac >>
  rw [msem_lift_monad_law] >>
  rw [ltree_lift_monad_law] >>
  drule itree_wbisim_bind_conv >>
  disch_tac >>
  pop_assum (assume_tac o (SPEC “(ltree_lift f st ∘ mrec_sem ∘ k):('a,'b) lktree”)) >>
  fs [o_THM]
QED

Theorem ltree_lift_compos:
  ltree_lift f st (mrec_sem (h_prog seed)) ≈ Ret x ⇒
  ltree_lift f st (mrec_sem (Vis (INL seed) k)) ≈ ltree_lift f st (mrec_sem (k x))
Proof
  disch_tac >>
  rw [panItreeSemTheory.mrec_sem_simps] >>
  rw [ltree_lift_cases] >>
  rw [ltree_lift_bind_left_ident]
QED

Theorem mrec_sem_bind_thm:
  (mrec_sem (itree_bind (Ret x) k) = mrec_sem (k x)) ∧
  (mrec_sem (itree_bind (Tau u) k) = Tau $ mrec_sem (itree_bind u k)) ∧
  (mrec_sem (itree_bind (Vis e g) k) = mrec_sem (Vis e (λx. itree_bind (g x) k)))
Proof
  rpt strip_tac >>
  rw [panItreeSemTheory.mrec_sem_simps]
QED

Theorem mrec_sem_leaf_compos:
  leaf_of ffis (mrec_sem (rh seed)) = Return x ⇒
  leaf_of ffis (mrec_sem (Vis (INL seed) k)) = leaf_of ffis (mrec_sem (k x))
Proof
  cheat
QED

Theorem fbs_sem_clock_inv_thm:
  FST $ evaluate (prog,s) = SOME Error ⇒
  FST $ evaluate (prog,s with clock := k) = SOME Error
Proof
  cheat
QED
*)

(* Main correspondence theorem *)

(* Extension for ffi$behaviour capturing evaluation result
 of convergent computations *)
Datatype:
  bstate =
    <| locals      : varname |-> 'a v
     ; code        : funname |-> ((varname # shape) list # ('a panLang$prog))
                     (* arguments (with shape), body *)
     ; eshapes     : eid |-> shape
     ; memory      : 'a word -> 'a word_lab
     ; memaddrs    : ('a word) set
     ; sh_memaddrs    : ('a word) set
     ; be          : bool
     ; ffi         : 'ffi ffi_state
     ; base_addr   : 'a word |>
End

Definition unclock_def:
  unclock (s:('a,'b) panSem$state) =
    <| locals      := s.locals
     ; code        := s.code
     ; eshapes     := s.eshapes
     ; memory      := s.memory
     ; memaddrs    := s.memaddrs
     ; sh_memaddrs := s.sh_memaddrs
     ; be          := s.be
     ; ffi         := s.ffi
     ; base_addr   := s.base_addr
|>
End  

Datatype:
  sem_behaviour =
    SemDiverge (io_event llist)
    | SemTerminate (('a result option) # ('a,'b) bstate) (io_event list)
    | SemFail
End

Definition fbs_semantics_beh_def:
  fbs_semantics_beh s prog =
  if ∃k. FST $ panSem$evaluate (prog,s with clock := k) ≠ SOME TimeOut
  then (case some (r,s'). ∃k. evaluate (prog,s with clock := k) = (r,s') ∧ r ≠ SOME TimeOut of
         SOME (r,s') => let s' = unclock s' in
                        (case r of
                           SOME (Return _) => SemTerminate (r,s') s'.ffi.io_events
                         | SOME (FinalFFI _) => SemTerminate (r,s') s'.ffi.io_events
                         | SOME Error => SemFail
                         | _ =>  SemTerminate (r,s') s'.ffi.io_events)
       | NONE => SemFail)
  else SemDiverge (build_lprefix_lub
                   (IMAGE (λk. fromList
                               (SND (evaluate (prog,s with clock := k))).ffi.io_events) UNIV))
End

Definition itree_semantics_beh_def:
  itree_semantics_beh s prog =
  let lt = ltree_lift query_oracle s.ffi (mrec_sem (h_prog (prog,s))) in
      case some (r,s'). lt ≈ Ret (r,s') of
      | SOME (r,s') => let s' = unclock s' in
                         (case r of
                      SOME TimeOut => SemTerminate (r,s') s'.ffi.io_events
                    | SOME (FinalFFI _) => SemTerminate (r,s') s'.ffi.io_events
                    | SOME (Return _) => SemTerminate (r,s') s'.ffi.io_events
                    | SOME Error => SemFail
                    | _ => SemTerminate (r,s') s'.ffi.io_events)
      | NONE => SemDiverge (stree_trace query_oracle s.ffi (to_stree (mrec_sem (h_prog (prog,s)))))
End

Theorem itree_sem_div_compos_thm:
  itree_semantics_beh (s with locals := s.locals |+ (v,x)) prog = SemDiverge l ⇒
  itree_semantics_beh s (Dec v e prog) = SemDiverge l
Proof
  cheat
QED

Theorem fbs_sem_div_compos_thm:
  fbs_semantics_beh s (Dec v e prog) = SemDiverge l ∧
  eval s e = SOME x ⇒
  fbs_semantics_beh (s with locals := s.locals |+ (v,x)) prog = SemDiverge l
Proof
  rpt strip_tac>>
  fs[fbs_semantics_beh_def,Once panSemTheory.evaluate_def] >>
  fs[bool_case_eq]>-
  rpt (FULL_CASE_TAC>>fs[])>>
  disj2_tac>>
  conj_tac>-
   (strip_tac>>first_x_assum $ qspec_then ‘k’ assume_tac>>
    FULL_CASE_TAC>>fs[]>>
    pairarg_tac>>fs[]>>gvs[panPropsTheory.eval_upd_clock_eq])>>
  irule lprefix_lubTheory.IMP_build_lprefix_lub_EQ>>
  conj_asm1_tac>-
   (simp[lprefix_chain_def]>>
    rpt strip_tac>>fs[]>>
    Cases_on ‘k' < k’>-
     (disj2_tac>>
      simp[LPREFIX_def,from_toList]>>
      irule IS_PREFIX_TRANS>>
      irule_at Any panPropsTheory.evaluate_add_clock_io_events_mono>>
      qexists_tac ‘k - k'’>>fs[])>>
    fs[NOT_LESS]>>
    disj1_tac>>
    simp[LPREFIX_def,from_toList]>>
    irule IS_PREFIX_TRANS>>
    irule_at Any panPropsTheory.evaluate_add_clock_io_events_mono>>
    qexists_tac ‘k' - k’>>fs[])>>
  conj_asm1_tac>-
   (simp[lprefix_chain_def]>>
    rpt strip_tac>>fs[]>>
    Cases_on ‘k' < k’>-
     (disj2_tac>>
      simp[LPREFIX_def,from_toList]>>
      irule IS_PREFIX_TRANS>>
      irule_at Any panPropsTheory.evaluate_add_clock_io_events_mono>>
      qexists_tac ‘k - k'’>>fs[])>>
    fs[NOT_LESS]>>
    disj1_tac>>
    simp[LPREFIX_def,from_toList]>>
    irule IS_PREFIX_TRANS>>
    irule_at Any panPropsTheory.evaluate_add_clock_io_events_mono>>
    qexists_tac ‘k' - k’>>fs[])>>
  conj_tac>-
   (simp[lprefix_rel_def]>>
    rpt strip_tac>>
    simp[PULL_EXISTS]>>
    simp[LPREFIX_def,from_toList]>>
    simp[Once panSemTheory.evaluate_def,
         panPropsTheory.eval_upd_clock_eq]>>
    pairarg_tac>>fs[]>>
    qexists_tac ‘k’>>fs[])>>
  simp[lprefix_rel_def]>>
  rpt strip_tac>>
  simp[PULL_EXISTS]>>
  simp[LPREFIX_def,from_toList]>>
  simp[SimpR “isPREFIX”, Once panSemTheory.evaluate_def,
       panPropsTheory.eval_upd_clock_eq]>>
  qexists_tac ‘k’>>
  pairarg_tac>>fs[]
QED

Theorem fbs_sem_conv_compos_thm:
  fbs_semantics_beh s (Dec v e prog) = SemTerminate p l ∧
  eval s e = SOME x ⇒
  fbs_semantics_beh (s with locals := s.locals |+ (v,x)) prog = SemTerminate p l
Proof
  cheat
QED

Theorem itree_sem_conv_compos_thm:
  itree_semantics_beh (s with locals := s.locals |+ (v,x)) prog = SemTerminate p l ⇒
  itree_semantics_beh s (Dec v e prog) = SemTerminate p l
Proof
  cheat
QED

Theorem fbs_sem_fail_compos_thm:
  fbs_semantics_beh s (Dec v e prog) = SemFail ∧
  eval s e = SOME x ⇒
  fbs_semantics_beh (s with locals := s.locals |+ (v,x)) prog = SemFail
Proof
  cheat
QED

Theorem itree_sem_fail_compos_thm:
  itree_semantics_beh (s with locals := s.locals |+ (v,x)) prog = SemFail ⇒
  itree_semantics_beh s (Dec v e prog) = SemFail
Proof
  cheat
QED

Theorem fbs_semantics_beh_simps:
  (∃k. fbs_semantics_beh s Skip = SemTerminate (NONE,unclock s) s.ffi.io_events) ∧
  (eval s e = NONE ⇒ fbs_semantics_beh s (Dec v e prog) ≠ SemTerminate p l)
Proof
  rw []
  >- (rw [fbs_semantics_beh_def,
          panSemTheory.evaluate_def] >>
      DEEP_INTRO_TAC some_intro >> rw [EXISTS_PROD] >>
      ntac 2 TOP_CASE_TAC >>
      pairarg_tac >> gvs [unclock_def])>>
  rw [fbs_semantics_beh_def,
      panSemTheory.evaluate_def] >>
  rw [panPropsTheory.eval_upd_clock_eq] >>
  DEEP_INTRO_TAC some_intro >> rw [] >>
  FULL_CASE_TAC >> fs [unclock_def]
QED

Theorem itree_wbisim_neq:
  Ret r ≈ Ret r' ⇔ r = r'
Proof
  EQ_TAC >>
  rw [Once itreeTauTheory.itree_wbisim_cases]
QED

Theorem itree_semantics_beh_simps:
  (itree_semantics_beh s Skip = SemTerminate (NONE, unclock s) s.ffi.io_events) ∧
  (eval s e = NONE ⇒
   itree_semantics_beh s (Dec v e prog) = SemFail)
Proof
  rw []
  >- (rw [itree_semantics_beh_def] >>
      DEEP_INTRO_TAC some_intro >> rw []
      >- (ntac 2 TOP_CASE_TAC >>
          fs [panItreeSemTheory.h_prog_def,unclock_def,
              panItreeSemTheory.mrec_sem_simps] >>
          fs [ltree_lift_cases] >>
          fs [Once itreeTauTheory.itree_wbisim_cases]) >>
      simp[EXISTS_PROD]>>
      fs [panItreeSemTheory.h_prog_def,unclock_def,
          panItreeSemTheory.mrec_sem_simps] >>
      fs [ltree_lift_cases] >>
      fs [Once itreeTauTheory.itree_wbisim_cases])>>
  rw [itree_semantics_beh_def]>>
  DEEP_INTRO_TAC some_intro >> rw [EXISTS_PROD]>>
  fs [itree_semantics_beh_def,unclock_def,
      panItreeSemTheory.h_prog_def,
      panItreeSemTheory.h_prog_rule_dec_def] >>
  rpt CASE_TAC>>gvs[]>>
  fs [ltree_lift_cases,
      panItreeSemTheory.mrec_sem_simps] >>
  fs [Once itreeTauTheory.itree_wbisim_cases]
QED

Theorem fbs_semantics_beh_cases:
  fbs_semantics_beh s prog = SemDiverge l ⇔
  (∀k. FST (evaluate (prog,s with clock := k)) = SOME TimeOut) ∧
  l = LUB (IMAGE
           (λk. fromList
                (SND (evaluate (prog,s with clock := k))).ffi.io_events) 𝕌(:num))
Proof
  EQ_TAC
  >- (rpt strip_tac >>>
          TRYALL (fs [fbs_semantics_beh_def] >>
                  rpt (FULL_CASE_TAC >> gvs [])))
  >- (rw [fbs_semantics_beh_def])
QED

Theorem nat_not_const_eq:
  ¬(∀k:num. k = 0)
Proof
  rw []
QED

Theorem itree_semantics_beh_clock_lem:
  itree_semantics_beh (s with clock := k) p = itree_semantics_beh s p
Proof
  cheat
QED

Theorem itree_semantics_beh_dec_clock_lem[simp]:
  itree_semantics_beh (dec_clock s) p = itree_semantics_beh s p
Proof
  cheat
QED

Theorem itree_wbisim_ret_decomp_eq:
  Ret r ≈ Ret r' ⇔
  r = r'
Proof
  EQ_TAC >>
  rw [Once itreeTauTheory.itree_wbisim_cases]
QED

Theorem itree_wbisim_ret_pair_decomp_eq:
  Ret (a,b) ≈ Ret (a',b') ⇔
  a = a' ∧ b = b'
Proof
  EQ_TAC >>
  rw [Once itreeTauTheory.itree_wbisim_cases]
QED

Theorem itree_sem_while_fails:
  eval s e = x ∧ (x = NONE ∨ x = SOME (ValLabel v1) ∨ x = SOME (Struct v2)) ⇒
  itree_semantics_beh s (While e c) = SemFail
Proof
  rw [itree_semantics_beh_def] >>
  gvs [panItreeSemTheory.h_prog_def,
       panItreeSemTheory.h_prog_rule_while_def,
       Once itreeTauTheory.itree_iter_thm,
       panItreeSemTheory.mrec_sem_simps,
       ltree_lift_cases] >>
  DEEP_INTRO_TAC some_intro >> rw [] >>>
  ALLGOALS (fs [ELIM_UNCURRY] >>
   fs [itree_wbisim_ret_decomp_eq] >> rw [])
  ORELSE (qexists_tac ‘(SOME Error,s)’ >>
          rw [itreeTauTheory.itree_wbisim_refl])
QED

Theorem itree_sem_while_no_loop:
  eval s e = SOME (ValWord 0w) ⇒
  itree_semantics_beh s (While e c) = SemTerminate (NONE,unclock s) s.ffi.io_events
Proof
  rw [itree_semantics_beh_def] >>
  gvs [panItreeSemTheory.h_prog_def,unclock_def,
       panItreeSemTheory.h_prog_rule_while_def,
       Once itreeTauTheory.itree_iter_thm,
       panItreeSemTheory.mrec_sem_simps,
       ltree_lift_cases] >>
  DEEP_INTRO_TAC some_intro >> rw [] >>>
  ALLGOALS (fs [ELIM_UNCURRY] >>
   fs [itree_wbisim_ret_decomp_eq] >> rw [])
  ORELSE (qexists_tac ‘(SOME Error,s)’ >>
          rw [itreeTauTheory.itree_wbisim_refl])
QED

(** clock independence **)
(* need newer HOL for this:
Coinductive clk_indep:
[~tau:]
  (clk_indep (t:('a,'b) htree) t' ⇒ clk_indep (Tau t) (Tau t'))
[~vis:]
  ((case (e,e') of
      (INL (r,s),INL (r,s')) => r = r' ∧ unclock s = unclock s'
    | (INR (r,s),INR (r,s')) => r = r' ∧ unclock s = unclock s'
    | _ => F) ∧
   (∀a. clk_indep (g a) (g' a)) ⇒ clk_indep (Vis e g) (Vis e' g'))
[~ret:]
  (r=r' ∧ unclock s = unclock s' ⇒ clk_indep (Ret (r,s)) (Ret (rr,s)))
End
*)

CoInductive clk_indep:
  (clk_indep (t:('a,'b) htree) t' ⇒ clk_indep (Tau t) (Tau t')) ∧
  ((case (e,e') of
    | (INL (r,s),INL (r',s')) => r = r' ∧ unclock s = unclock s'
    | (INR (r,f),INR (r',f')) => r = r' ∧
                                 (∀a. unclock (SND (f a)) = unclock (SND (f' a)))
    | _ => F) ∧
   (∀a. clk_indep (g a) (g' a)) ⇒ clk_indep (Vis e g) (Vis e' g')) ∧
  (r=r' ∧ unclock s = unclock s' ⇒ clk_indep (Ret (r,s)) (Ret (r',s')))
End
    
Theorem h_prog_clock_shift:
  ∀prog s k. mrec_sem (h_prog (prog,s)) = mrec_sem (h_prog (prog,s with clock := k))
Proof

Theorem h_prog_clock_clk_indep:
  clk_indep (h_prog (prog,s)) (h_prog (prog,s with clock := k))
Proof
  irule clk_indep_coind>>
  qexists_tac ‘λx y. ∃k. x = h_prog (prog, s) ∧
                                y = h_prog (prog, s with clock := k)’>>
  reverse $ rw[]>- metis_tac[]>>
        
  MAP_EVERY qid_spec_tac [‘k’,‘s’,‘prog’]>>
  recInduct panItreeSemTheory.h_prog_ind>>
  rw [panItreeSemTheory.h_prog_def,
      panItreeSemTheory.h_prog_rule_dec_def,
      panItreeSemTheory.h_prog_rule_assign_def,
      panItreeSemTheory.h_prog_rule_store_def,
      panItreeSemTheory.h_prog_rule_store_byte_def,
      panItreeSemTheory.h_prog_rule_shmem_def,
      panItreeSemTheory.h_prog_rule_seq_def,
      panItreeSemTheory.h_prog_rule_cond_def,
      panItreeSemTheory.h_prog_rule_raise_def,
      panItreeSemTheory.h_prog_rule_return_def,
      panItreeSemTheory.h_prog_rule_tick_def,
      panItreeSemTheory.h_prog_rule_while_def,
     panPropsTheory.eval_upd_clock_eq]>>
  TRY (simp[unclock_def]>>NO_TAC)>>

  CASE_TAC>>fs[]>>
  pairarg_tac>>fs[]>>metis_tac[]

simp[unclock_def]

QED

Theorem clock2:
  ∀prog s. 
  h_prog (prog, s) = Ret x ⇒
  ∃y. h_prog (prog, s with clock := k + s.clock) = Ret y ∧
      FST y = FST x ∧ unclock (SND y) = unclock (SND x)
Proof
  recInduct panItreeSemTheory.h_prog_ind>>
  rw [panItreeSemTheory.h_prog_def,
      panItreeSemTheory.h_prog_rule_dec_def,
      panItreeSemTheory.h_prog_rule_assign_def,
      panItreeSemTheory.h_prog_rule_store_def,
      panItreeSemTheory.h_prog_rule_store_byte_def,
(*      panItreeSemTheory.h_prog_rule_shmem_def,*)
      panItreeSemTheory.h_prog_rule_call_def,
      panItreeSemTheory.h_prog_rule_ext_call_def,
      panItreeSemTheory.h_prog_rule_seq_def,
      panItreeSemTheory.h_prog_rule_cond_def,
      panItreeSemTheory.h_prog_rule_raise_def,
      panItreeSemTheory.h_prog_rule_return_def,
      panItreeSemTheory.h_prog_rule_tick_def,
      panItreeSemTheory.h_prog_rule_while_def,
      panPropsTheory.eval_upd_clock_eq]>>
  TRY (fs[unclock_def]>>NO_TAC)>>fs[]>>
  rpt (CASE_TAC>>fs[])>>

  gvs[unclock_def,panSemTheory.empty_locals_def,panSemTheory.dec_clock_def]
cheat (* tick *)
cheat (* shmem *)
(rpt (FULL_CASE_TAC>>fs[])>>gvs[]>>
 fs[Once itreeTauTheory.itree_iter_thm,
    panPropsTheory.eval_upd_clock_eq]>>
 rpt (CASE_TAC>>gvs[unclock_def]))>-
   (rpt (FULL_CASE_TAC>>fs[])>>gvs[unclock_def]>>
    fs[panPropsTheory.eval_upd_clock_eq]>>
    fs[panSemTheory.lookup_code_def,option_case_eq]>>
    FULL_CASE_TAC>>gvs[])>>
  rpt (CASE_TAC>>fs[])>>gvs[unclock_def]
QED

Theorem clock1:
  mrec_sem (h_prog (prog, s)) = Ret x ⇒
  ∃y. mrec_sem (h_prog (prog, s with clock := k + s.clock)) = Ret y ∧
      FST y = FST x ∧ unclock (SND y) = unclock (SND x)
Proof
  strip_tac>>
  fs[panItreeSemTheory.mrec_sem_def]>>
  Cases_on ‘h_prog (prog,s)’>>fs[]>-
   (imp_res_tac clock2>>
    first_x_assum $ qspec_then ‘k’ assume_tac>>
    fs[]>>
    gvs[Once itreeTauTheory.itree_iter_thm]>>
    gvs[Once itreeTauTheory.itree_iter_thm])>-
   gvs[Once itreeTauTheory.itree_iter_thm]>>
  Cases_on ‘a’>>
  gvs[Once itreeTauTheory.itree_iter_thm]>>
  pairarg_tac>>fs[]
QED


Theorem clock0:
  ltree_lift query_oracle s.ffi (mrec_sem (h_prog (prog,s))) = Ret (r,s') ⇒
  ∀k. ∃r' s''. ltree_lift query_oracle s.ffi (mrec_sem (h_prog (prog,s with clock := s.clock + k))) = Ret (r',s'') ∧ r' = r ∧ unclock s' = unclock s''
Proof
  strip_tac>>
  strip_tac>>
  fs[ltree_lift_def]>>
  Cases_on ‘mrec_sem (h_prog (prog,s))’>>fs[]>-
   (imp_res_tac clock1>>
    first_x_assum $ qspec_then ‘k’ assume_tac>>
    fs[]>>
    gvs[Once itreeTauTheory.itree_iter_thm]>>
    gvs[Once itreeTauTheory.itree_iter_thm]>>
    Cases_on ‘y’>>gvs[])>-
   gvs[Once itreeTauTheory.itree_iter_thm]>>
  Cases_on ‘a’>>
  gvs[Once itreeTauTheory.itree_iter_thm]>>
  pairarg_tac>>fs[]
QED


Theorem itree_beh_clock_shift:
  itree_semantics_beh s prog = itree_semantics_beh (s with clock := k) prog
Proof
  simp[itree_semantics_beh_def]>>
  DEEP_INTRO_TAC some_intro >> rw [] >>
  DEEP_INTRO_TAC some_intro >> rw [] >-

   (ntac 2 (CASE_TAC>>fs[])>>
    TRY (ntac 2 (CASE_TAC>>fs[]))>>
    imp_res_tac clock0>>
    first_x_assum $ qspec_then ‘k’ assume_tac>>fs[]>>
    drule itreeTauTheory.itree_wbisim_sym>>strip_tac>>
    drule itreeTauTheory.itree_wbisim_trans>>
    disch_then $ rev_drule_at Any>>
    simp[Once itreeTauTheory.itree_wbisim_cases]>>
    gvs[FORALL_PROD,ltree_lift_cases,unclock_def])>>



  fs[LAMBDA_PROD,FORALL_PROD]
        
  
  recInduct panItreeSemTheory.h_prog_ind>>
  rw [panItreeSemTheory.h_prog_def,
      panItreeSemTheory.h_prog_rule_dec_def,
      panItreeSemTheory.h_prog_rule_assign_def,
      panItreeSemTheory.h_prog_rule_store_def,
      panItreeSemTheory.h_prog_rule_store_byte_def,
      panItreeSemTheory.h_prog_rule_shmem_def,
      panItreeSemTheory.h_prog_rule_seq_def,
      panItreeSemTheory.h_prog_rule_cond_def,
      panItreeSemTheory.h_prog_rule_raise_def,
      panItreeSemTheory.h_prog_rule_return_def,
      panItreeSemTheory.h_prog_rule_tick_def,
      panItreeSemTheory.h_prog_rule_while_def]>>
  simp[Once itreeTauTheory.itree_iter_thm,
       panItreeSemTheory.mrec_sem_simps,
       panPropsTheory.eval_upd_clock_eq,
       ltree_lift_cases] >>
(*  fs [Once itreeTauTheory.itree_wbisim_cases]>>*)
  TRY
  (DEEP_INTRO_TAC some_intro >> rw [] >>
  DEEP_INTRO_TAC some_intro >> rw [] >>
  rpt CASE_TAC>>fs[unclock_def,FORALL_PROD]>>
  fs [Once itreeTauTheory.itree_wbisim_cases]>>NO_TAC)


  (* dec *)
  CASE_TAC>>fs[]>>
  DEEP_INTRO_TAC some_intro >> rw [] >>
  DEEP_INTRO_TAC some_intro >> rw [] >>
  rpt (CASE_TAC>>fs[])>>
  fs [panItreeSemTheory.mrec_sem_simps,ltree_lift_cases,
      Once itreeTauTheory.itree_wbisim_cases,
      Once itreeTauTheory.strip_tau_cases,
      unclock_def,FORALL_PROD]>>



  rpt CASE_TAC>>fs[unclock_def,FORALL_PROD]>>




  gvs [panItreeSemTheory.h_prog_def,unclock_def,
       panItreeSemTheory.h_prog_rule_while_def,
       Once itreeTauTheory.itree_iter_thm,
       panItreeSemTheory.mrec_sem_simps,
       ltree_lift_cases] >>

  
QED

(** end : clock **)

(* TODO: Need to prove the correspondence for While more directly
 to better understand what is required here... *)
Theorem itree_semantics_corres:
  fbs_semantics_beh s prog = itree_semantics_beh s prog
Proof
  rw [fbs_semantics_beh_def]
  >- (DEEP_INTRO_TAC some_intro >> reverse $ rw []
      >- (gvs [ELIM_UNCURRY]) >>
      pairarg_tac >> gvs [] >>
      CONV_TAC SYM_CONV >>
      last_x_assum kall_tac >>
      ‘itree_semantics_beh s prog = itree_semantics_beh (s with clock := k') prog’ by (cheat) >>
      pop_assum (SUBST_ALL_TAC) >>
      rename1 ‘itree_semantics_beh t’ >>
      rpt $ pop_assum MP_TAC >>
      MAP_EVERY qid_spec_tac [‘s'’,‘r’,‘t’,‘prog’] >>
      recInduct panSemTheory.evaluate_ind >> rw []
      >~ [‘While’]
      >- (rgs [Once panSemTheory.evaluate_def,
               AllCaseEqs()] >> gvs []
          >- (rw [itree_sem_while_fails])
          >- (pairarg_tac >> gvs [AllCaseEqs()]
              >- (ntac 2 $ last_x_assum (assume_tac o GSYM) >> rw [] >>
                  CONV_TAC SYM_CONV >>
                  (* THIS IS VERY STRANGE... the states are messed up. *)
                  cheat) >>
              cheat)
          >- fs[itree_sem_while_no_loop,unclock_def]
          >- (rw [itree_sem_while_fails])
          >- (rw [itree_sem_while_fails])) >>
      (* All remaining terms... for convg case *)
      cheat)
  (* Div *)
  >- (CONV_TAC SYM_CONV >>
      Cases_on ‘itree_semantics_beh s prog’ >>
      simp []
      >- (irule (iffLR lprefix_lubTheory.build_prefix_lub_intro) >>
          rw []
          >- (cheat)
          >- (simp [lprefix_lubTheory.lprefix_lub_def] >>
              conj_asm1_tac
              >- (cheat)
              >- (rw [] >>
                  (* Prove l is the least prefix *)
                  cheat)
              >- (cheat)
              >- (cheat))))
     (*    Cases_on ‘eval s e’ *)
     (* >- (fs [Once panSemTheory.evaluate_def, *)
     (*         panPropsTheory.eval_upd_clock_eq]) *)
     (* >- (Cases_on ‘x’ >> gvs [] *)
     (*     >- (Cases_on ‘w’ >> gvs [] *)
     (*         >- (Cases_on ‘c' ≠ 0w’ >> gvs [] *)
     (*             >- (Cases_on ‘s'.clock’ >> gvs [] *)
     (*                ) *)
     (*            ) *)
     (*        ) *)
     (*    Cases_on ‘fbs_semantics_beh s prog’ *)
     (* (* Div *) *)
     (* >-  (fs [fbs_semantics_beh_cases] >> *)
     (*      CONV_TAC SYM_CONV >> *)
     (*      Q.PAT_UNDISCH_TAC ‘∀k. _ = SOME TimeOut’ >> *)
     (*      qid_spec_tac ‘s’ >> *)
     (*      qid_spec_tac ‘prog’ >> *)
     (*      recInduct panSemTheory.evaluate_ind >> *)
     (*      rw [] *)
     (*      (* While *) *)
     (*      >- (Cases_on ‘eval s' e’ *)
     (*          >- (fs [Once panSemTheory.evaluate_def, *)
     (*                  panPropsTheory.eval_upd_clock_eq]) *)
     (*          >- (Cases_on ‘x’ >> gvs [] *)
     (*              >- (Cases_on ‘w’ >> gvs [] *)
     (*                  >- (Cases_on ‘c' ≠ 0w’ >> gvs [] *)
     (*                      >- (Cases_on ‘s'.clock’ >> gvs [] *)
     (*                         ) *)
     (*                     ) *)
     (*                 ) *)
     (*             ) *)
     (*         ) *)
     (*      (* Skip *) *)
     (*      >- (Cases_on ‘fbs_semantics_beh s Skip’ >> *)
     (*          fs [fbs_semantics_beh_simps] *)
     (*          (* Fail is equiv *) *)
     (*          >- (rw [itree_semantics_beh_simps])) *)
     (*      (* Dec *) *)
     (*      >- (Cases_on ‘fbs_semantics_beh s (Dec v e prog)’ *)
     (*          (* Div *) *)
     (*          >- (Cases_on ‘eval s e’ >> rw [] *)
     (*              >- (fs [fbs_semantics_beh_def, *)
     (*                      panSemTheory.evaluate_def] >> *)
     (*                  gvs [panPropsTheory.eval_upd_clock_eq] >> *)
     (*                  UNDISCH_TAC “(case *)
     (*                               some(r,s'). ∃k. *)
     (*                                 (r = SOME Error ∧ s with clock := k = s') ∧ r ≠ SOME TimeOut *)
     (*                               of *)
     (*                                 NONE => SemFail *)
     (*                               | SOME (r,s') => *)
     (*                                   case r of *)
     (*                                     NONE => SemFail *)
     (*                                   | SOME Error => SemFail *)
     (*                                   | SOME TimeOut => SemFail *)
     (*                                   | SOME Break => SemFail *)
     (*                                   | SOME Continue => SemFail *)
     (*                                   | SOME (Return v6) => SemTerminate (r,s') s'.ffi.io_events *)
     (*                                   | SOME (Exception v7 v8) => SemFail *)
     (*                                   | SOME (FinalFFI v9) => SemTerminate (r,s') s'.ffi.io_events) = *)
     (*                               SemDiverge l” >> *)
     (*                  DEEP_INTRO_TAC some_intro >> rw [] >> *)
     (*                  FULL_CASE_TAC >> gvs []) *)
     (*              >- (drule fbs_sem_div_compos_thm >> disch_tac >> *)
     (*                  gvs [] >> *)
     (*                  ‘SemDiverge l = itree_semantics_beh s (Dec v e prog)’ suffices_by (gvs []) >> *)
     (*                  irule (GSYM itree_sem_div_compos_thm) >> *)
     (*                  qexists_tac ‘x’ >> rw [])) *)
     (*          (* Conv *) *)
     (*          >- (Cases_on ‘eval s e’ >> rw [] *)
     (*              >- (fs [fbs_semantics_beh_simps]) *)
     (*              >- (drule fbs_sem_conv_compos_thm >> disch_tac >> *)
     (*                  gvs [] >> *)
     (*                  ‘SemTerminate p l = itree_semantics_beh s (Dec v e prog)’ suffices_by (gvs []) >> *)
     (*                  irule (GSYM itree_sem_conv_compos_thm) >> *)
     (*                  qexists_tac ‘x’ >> rw [])) *)
     (*          (* Fail *) *)
     (*          >- (Cases_on ‘eval s e’ >> rw [] *)
     (*              >- (fs [itree_semantics_beh_simps]) *)
     (*              >- (drule fbs_sem_fail_compos_thm >> disch_tac >> *)
     (*                  gvs [] >> *)
     (*                  irule itree_sem_fail_compos_thm >> *)
     (*                  qexists_tac ‘x’ >> rw []))) *)
     (*      (* Assign *) *)
     (*      >- (Cases_on ‘fbs_semantics_beh s (Assign v src)’ >> *)
     (*          fs [fbs_semantics_beh_simps] >> rw [] >> *)
     (*          rw [itree_semantics_beh_simps]) *)
     (*      (* Store *) *)
     (*      >- (Cases_on ‘fbs_semantics_beh s (Store dst src)’ >> *)
     (*         ) *)
     (*     ) *)
QED

Theorem evaluate_mtree_path_corr_ltree:
  ∀p s. s.clock = k ∧ s.ffi = ffis ⇒
        ltree_lift query_oracle s.ffi (mrec_sem $ h_prog (p,s)) ≈ Ret (evaluate (p,s))
Proof
  recInduct panSemTheory.evaluate_ind >>
  rpt strip_tac
  (* Skip *)
  >- (rw [panSemTheory.evaluate_def] >>
      rw [panItreeSemTheory.h_prog_def] >>
      rw [panItreeSemTheory.mrec_sem_simps] >>
      rw [ltree_lift_cases] >>
      rw [itreeTauTheory.itree_wbisim_refl])
  (* Dec *)
  >- (Cases_on ‘eval s e’
      >- (rw [panItreeSemTheory.h_prog_def,
              panItreeSemTheory.h_prog_rule_dec_def] >>
          rw [panItreeSemTheory.mrec_sem_simps] >>
          rw [panSemTheory.evaluate_def] >>
          rw [ltree_lift_cases] >>
          rw [itreeTauTheory.itree_wbisim_refl])
      >- (rw [] >>
          rw [panItreeSemTheory.h_prog_def,
              panItreeSemTheory.h_prog_rule_dec_def] >>
          drule ltree_lift_compos >>
          disch_tac >>
          rw [panSemTheory.evaluate_def] >>
          Cases_on ‘evaluate (prog,s with locals := s.locals |+ (v,x))’ >>
          rw [] >>
          pop_assum kall_tac >>
          pop_assum (assume_tac o (SPEC “(λ(res,s'). Ret (res,s' with locals := res_var s'.locals (v,FLOOKUP (s:('a,'b) state).locals v))):('a,'b) hktree”)) >>
          fs [panItreeSemTheory.mrec_sem_simps,
              ltree_lift_cases]) >>
      cheat) >>
  cheat
QED



(* Final goal:

   1. For every path that can be generated frong

   that produces an equivalent result in the functional semantics.
   2. For every oracle, there is a path producing a corresponding result in the ITree semantics.
 *)

val _ = export_theory();
