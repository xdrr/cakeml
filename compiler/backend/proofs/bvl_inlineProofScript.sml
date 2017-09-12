open preamble
     bvlSemTheory bvlPropsTheory
     bvl_inlineTheory;

val _ = new_theory"bvl_inlineProof";

(* removal of ticks *)

val remove_ticks_def = tDefine "remove_ticks" `
  (remove_ticks [] = []) /\
  (remove_ticks (x::y::xs) =
     HD (remove_ticks [x]) :: remove_ticks (y::xs)) /\
  (remove_ticks [Var v] = [Var v]) /\
  (remove_ticks [If x1 x2 x3] =
     [If (HD (remove_ticks [x1]))
         (HD (remove_ticks [x2]))
         (HD (remove_ticks [x3]))]) /\
  (remove_ticks [Let xs x2] =
     [Let (remove_ticks xs) (HD (remove_ticks [x2]))]) /\
  (remove_ticks [Raise x1] =
     [Raise (HD (remove_ticks [x1]))]) /\
  (remove_ticks [Handle x1 x2] =
     [Handle (HD (remove_ticks [x1]))
             (HD (remove_ticks [x2]))]) /\
  (remove_ticks [Op op xs] =
     [Op op (remove_ticks xs)]) /\
  (remove_ticks [Tick x] = remove_ticks [x]) /\
  (remove_ticks [Call ticks dest xs] =
     [Call 0 dest (remove_ticks xs)])`
  (WF_REL_TAC `measure exp1_size`);

val LENGTH_remove_ticks = store_thm("LENGTH_remove_ticks[simp]",
  ``!xs. LENGTH (remove_ticks xs) = LENGTH xs``,
  recInduct (theorem "remove_ticks_ind") \\ fs [remove_ticks_def]);

val remove_ticks_SING = store_thm("remove_ticks_SING[simp]",
  ``[HD (remove_ticks [r])] = remove_ticks [r]``,
  qsuff_tac `?a. remove_ticks [r] = [a]` \\ rw[] \\ fs []
  \\ `LENGTH (remove_ticks [r]) = LENGTH [r]` by fs [LENGTH_remove_ticks]
  \\ Cases_on `remove_ticks [r]` \\ fs []);

val state_rel_def = Define `
  state_rel (s:('c,'ffi) bvlSem$state) (t:('c,'ffi) bvlSem$state) <=>
    t = s with <| code := map (I ## (\x. HD (remove_ticks [x]))) s.code
                ; compile := t.compile
                ; compile_oracle := (I ##
      MAP (I ## I ## (\x. HD (remove_ticks [x])))) o s.compile_oracle |> /\
    s.compile = \cfg prog. t.compile cfg
                   (MAP (I ## I ## (\x. HD (remove_ticks [x]))) prog)`

val state_rel_alt = state_rel_def

val state_rel_def =
  state_rel_def |> SIMP_RULE (srw_ss()) [state_component_equality,GSYM CONJ_ASSOC];

val do_app_lemma = prove(
  ``state_rel t' r ==>
    case do_app op (REVERSE a) r of
    | Rerr err => do_app op (REVERSE a) t' = Rerr err
    | Rval (v,r2) => ?t2. state_rel t2 r2 /\ do_app op (REVERSE a) t' = Rval (v,t2)``,
  Cases_on `op = Install` THEN1
   (rw [] \\ fs [do_app_def]
    \\ every_case_tac \\ fs []
    \\ fs [case_eq_thms,UNCURRY,do_install_def]
    \\ rveq \\ fs [PULL_EXISTS]
    \\ fs [SWAP_REVERSE_SYM] \\ rveq \\ fs []
    \\ fs [state_rel_def] \\ rveq \\ fs []
    \\ fs [state_component_equality]
    THEN1
     (fs [shift_seq_def,o_DEF] \\ rfs []
      \\ Cases_on `t'.compile_oracle 0` \\ fs []
      \\ Cases_on `r'` \\ fs [] \\ Cases_on `h` \\ fs [] \\ rveq \\ fs []
      \\ fs [map_union] \\ AP_TERM_TAC
      \\ fs [map_fromAList] \\ AP_TERM_TAC \\ fs []
      \\ rpt (AP_THM_TAC ORELSE AP_TERM_TAC)
      \\ fs [FUN_EQ_THM,FORALL_PROD])
    \\ CCONTR_TAC \\ fs [] \\ rfs [FORALL_PROD,shift_seq_def]
    \\ metis_tac [list_nchotomy,PAIR])
  \\ strip_tac \\ Cases_on `do_app op (REVERSE a) t'`
  THEN1
   (rename1 `_ = Rval aa`
    \\ PairCases_on `aa`
    \\ drule (Q.GENL [`c`,`cc`,`co`] do_app_with_code) \\ fs []
    \\ fs [state_rel_alt]
    \\ disch_then (qspecl_then [`map (I ## (λx. HD (remove_ticks [x]))) t'.code`,
        `r.compile`,`(I ## MAP (I ## I ## (λx. HD (remove_ticks [x])))) ∘
          t'.compile_oracle`] mp_tac)
    \\ qpat_x_assum `r = _` (assume_tac o GSYM) \\ fs []
    \\ impl_tac THEN1 fs [domain_map]
    \\ strip_tac \\ fs []
    \\ qpat_x_assum `_ = r` (assume_tac o GSYM) \\ fs []
    \\ rw [] \\ fs [state_component_equality]
    \\ imp_res_tac do_app_const \\ fs [])
  \\ drule (Q.GENL [`c`,`cc`,`co`] do_app_with_code_err_not_Install) \\ fs []
  \\ fs [state_rel_alt]
  \\ disch_then (qspecl_then [`map (I ## (λx. HD (remove_ticks [x]))) t'.code`,
      `r.compile`,`(I ## MAP (I ## I ## (λx. HD (remove_ticks [x])))) ∘
        t'.compile_oracle`] mp_tac)
  \\ qpat_x_assum `r = _` (assume_tac o GSYM) \\ fs []
  \\ impl_tac THEN1 fs [domain_map] \\ fs []);

val evaluate_remove_ticks = Q.store_thm("evaluate_remove_ticks",
  `!k xs env s (t:('c,'ffi) bvlSem$state) res s'.
      state_rel t s /\ s.clock = k /\
      evaluate (remove_ticks xs,env,s) = (res,s') ==>
      ?ck t'. evaluate (xs,env,t with clock := t.clock + ck) = (res,t') /\
              state_rel t' s'`,
  strip_tac \\ completeInduct_on `k` \\ fs [PULL_FORALL,AND_IMP_INTRO]
  \\ recInduct (theorem "remove_ticks_ind") \\ rw []
  THEN1 (* NIL *)
   (fs [evaluate_def,remove_ticks_def] \\ rveq
    \\ qexists_tac `0` \\ fs [state_rel_def,state_component_equality])
  THEN1 (* CONS *)
   (fs [evaluate_def,remove_ticks_def]
    \\ pop_assum mp_tac \\ simp [Once evaluate_CONS]
    \\ TOP_CASE_TAC
    \\ qpat_x_assum `!x. _` mp_tac
    \\ first_x_assum drule \\ fs []
    \\ disch_then drule \\ strip_tac
    \\ reverse (Cases_on `q`) \\ fs []
    THEN1 (rw [] \\ fs [] \\ qexists_tac `ck` \\ fs [])
    \\ strip_tac
    \\ `∀env s' (t:('c,'ffi) bvlSem$state) res s''.
         state_rel t s' ∧ s'.clock <= s.clock ∧
         evaluate (remove_ticks (y::xs),env,s') = (res,s'') ⇒
         ∃ck t'.
           evaluate (y::xs,env,t with clock := ck + t.clock) = (res,t') ∧
           state_rel t' s''` by metis_tac [LESS_OR_EQ]
    \\ pop_assum drule
    \\ imp_res_tac evaluate_clock \\ fs []
    \\ TOP_CASE_TAC \\ disch_then drule \\ strip_tac
    \\ rw [] \\ qexists_tac `ck+ck'`
    \\ qpat_x_assum `evaluate ([x],_) = _` assume_tac
    \\ drule evaluate_add_clock \\ fs [inc_clock_def]
    \\ disch_then kall_tac
    \\ CASE_TAC \\ fs [])
  THEN1 (* Var *)
   (fs [evaluate_def,remove_ticks_def]
    \\ CASE_TAC \\ fs [] \\ rveq
    \\ qexists_tac `0` \\ fs [state_rel_def,state_component_equality])
  THEN1 (* If *)
   (fs [evaluate_def,remove_ticks_def]
    \\ pop_assum mp_tac \\ TOP_CASE_TAC
    \\ qpat_x_assum `!x. _` mp_tac
    \\ qpat_x_assum `!x. _` mp_tac
    \\ first_x_assum drule \\ fs []
    \\ disch_then drule \\ strip_tac
    \\ reverse (Cases_on `q`) \\ fs []
    THEN1 (rw [] \\ fs [] \\ qexists_tac `ck` \\ fs [])
    \\ TOP_CASE_TAC THEN1
     (disch_then assume_tac \\ disch_then kall_tac \\ strip_tac
      \\ `∀env s' (t:('c,'ffi) bvlSem$state) res s''.
           state_rel t s' ∧ s'.clock <= s.clock ∧
           evaluate (remove_ticks [x2],env,s') = (res,s'') ⇒
           ∃ck t'.
             evaluate ([x2],env,t with clock := ck + t.clock) = (res,t') ∧
             state_rel t' s''` by metis_tac [LESS_OR_EQ]
      \\ first_x_assum drule
      \\ imp_res_tac evaluate_clock \\ fs []
      \\ disch_then drule \\ strip_tac
      \\ rw [] \\ qexists_tac `ck+ck'`
      \\ qpat_x_assum `evaluate ([x1],_) = _` assume_tac
      \\ drule evaluate_add_clock \\ fs [inc_clock_def]
      \\ disch_then kall_tac)
    \\ TOP_CASE_TAC THEN1
     (disch_then kall_tac \\ disch_then assume_tac \\ strip_tac
      \\ `∀env s' (t:('c,'ffi) bvlSem$state) res s''.
           state_rel t s' ∧ s'.clock <= s.clock ∧
           evaluate (remove_ticks [x3],env,s') = (res,s'') ⇒
           ∃ck t'.
             evaluate ([x3],env,t with clock := ck + t.clock) = (res,t') ∧
             state_rel t' s''` by metis_tac [LESS_OR_EQ]
      \\ first_x_assum drule
      \\ imp_res_tac evaluate_clock \\ fs []
      \\ disch_then drule \\ strip_tac
      \\ rw [] \\ qexists_tac `ck+ck'`
      \\ qpat_x_assum `evaluate ([x1],_) = _` assume_tac
      \\ drule evaluate_add_clock \\ fs [inc_clock_def]
      \\ disch_then kall_tac)
    \\ rw [] \\ qexists_tac `ck` \\ fs [])
  THEN1 (* Let *)
   (fs [evaluate_def,remove_ticks_def]
    \\ pop_assum mp_tac \\ TOP_CASE_TAC
    \\ qpat_x_assum `!x. _` mp_tac
    \\ first_x_assum drule \\ fs []
    \\ disch_then drule \\ strip_tac
    \\ reverse (Cases_on `q`) \\ fs []
    THEN1 (rw [] \\ fs [] \\ qexists_tac `ck` \\ fs [])
    \\ strip_tac
    \\ `∀env s' (t:('c,'ffi) bvlSem$state) res s''.
           state_rel t s' ∧ s'.clock <= s.clock ∧
           evaluate (remove_ticks [x2],env,s') = (res,s'') ⇒
           ∃ck t'.
             evaluate ([x2],env,t with clock := ck + t.clock) = (res,t') ∧
             state_rel t' s''` by metis_tac [LESS_OR_EQ]
    \\ first_x_assum drule
    \\ imp_res_tac evaluate_clock \\ fs []
    \\ rpt strip_tac \\ first_x_assum drule
    \\ rw [] \\ qexists_tac `ck+ck'`
    \\ qpat_x_assum `evaluate (xs,_) = _` assume_tac
    \\ drule evaluate_add_clock \\ fs [inc_clock_def])
  THEN1 (* Raise *)
   (fs [evaluate_def,remove_ticks_def]
    \\ pop_assum mp_tac \\ TOP_CASE_TAC
    \\ first_x_assum drule \\ fs []
    \\ disch_then drule \\ strip_tac
    \\ reverse (Cases_on `q`) \\ fs []
    \\ rw [] \\ fs [] \\ qexists_tac `ck` \\ fs [])
  THEN1 (* Handle *)
   (fs [evaluate_def,remove_ticks_def]
    \\ pop_assum mp_tac \\ TOP_CASE_TAC
    \\ qpat_x_assum `!x. _` mp_tac
    \\ first_x_assum drule \\ fs []
    \\ disch_then drule \\ strip_tac
    \\ Cases_on `q` \\ fs []
    THEN1 (rw [] \\ fs [] \\ qexists_tac `ck` \\ fs [])
    \\ reverse (Cases_on `e`) \\ fs []
    THEN1 (rw [] \\ fs [] \\ qexists_tac `ck` \\ fs [])
    \\ rpt strip_tac
    \\ `∀env s' (t:('c,'ffi) bvlSem$state) res s''.
           state_rel t s' ∧ s'.clock <= s.clock ∧
           evaluate (remove_ticks [x2],env,s') = (res,s'') ⇒
           ∃ck t'.
             evaluate ([x2],env,t with clock := ck + t.clock) = (res,t') ∧
             state_rel t' s''` by metis_tac [LESS_OR_EQ]
    \\ first_x_assum drule
    \\ imp_res_tac evaluate_clock \\ fs []
    \\ rpt strip_tac \\ first_x_assum drule
    \\ rw [] \\ qexists_tac `ck+ck'`
    \\ qpat_x_assum `evaluate ([x1],_) = _` assume_tac
    \\ drule evaluate_add_clock \\ fs [inc_clock_def])
  THEN1 (* Op *)
   (fs [remove_ticks_def,evaluate_def]
    \\ FULL_CASE_TAC \\ fs []
    \\ first_x_assum drule \\ fs []
    \\ disch_then drule \\ strip_tac
    \\ qexists_tac `ck` \\ fs []
    \\ reverse (Cases_on `q`) \\ fs [] \\ rveq \\ fs []
    \\ drule do_app_lemma \\ every_case_tac \\ fs []
    \\ rveq \\ fs [])
  THEN1 (* Tick *)
   (fs [remove_ticks_def]
    \\ first_x_assum drule \\ fs []
    \\ disch_then drule \\ strip_tac
    \\ fs [bvlSemTheory.evaluate_def]
    \\ qexists_tac `ck + 1` \\ fs [dec_clock_def])
  (* Call *)
  \\ fs [remove_ticks_def]
  \\ fs [bvlSemTheory.evaluate_def]
  \\ FULL_CASE_TAC \\ fs []
  \\ reverse (Cases_on `q`) \\ fs [] \\ rveq
  THEN1
   (first_x_assum drule \\ fs []
    \\ disch_then drule \\ strip_tac
    \\ qexists_tac `ck` \\ fs [])
  \\ pop_assum mp_tac
  \\ TOP_CASE_TAC \\ fs [] \\ rpt strip_tac \\ rveq \\ fs []
  THEN1
   (first_x_assum drule \\ fs []
    \\ disch_then drule \\ strip_tac
    \\ qexists_tac `ck` \\ fs []
    \\ qsuff_tac `find_code dest a t'.code = NONE` \\ fs []
    \\ Cases_on `dest` \\ fs [find_code_def]
    \\ every_case_tac \\ fs [state_rel_def]
    \\ rveq \\ fs [lookup_map]
    \\ rfs [lookup_map])
  \\ PairCases_on `x` \\ fs []
  \\ pop_assum mp_tac
  \\ IF_CASES_TAC \\ rw []
  THEN1
   (first_x_assum drule \\ fs []
    \\ disch_then drule \\ strip_tac
    \\ qexists_tac `ck` \\ fs []
    \\ qsuff_tac `?x1 x2. find_code dest a t'.code = SOME (x1,x2)`
    THEN1 (strip_tac \\ fs [] \\ fs [state_rel_def])
    \\ fs [state_rel_def] \\ rveq \\ fs []
    \\ Cases_on `dest` \\ fs [find_code_def]
    \\ every_case_tac \\ fs [] \\ rveq \\ fs [lookup_map] \\ fs []
    \\ PairCases_on `z` \\ fs [])
  \\ first_x_assum drule \\ fs []
  \\ disch_then drule \\ strip_tac
  \\ `(dec_clock 1 r).clock < s.clock` by
        (imp_res_tac evaluate_clock  \\ fs [dec_clock_def] \\ fs [])
  \\ first_x_assum drule
  \\ `state_rel (dec_clock 1 t') (dec_clock 1 r)` by fs [state_rel_def,dec_clock_def]
  \\ disch_then drule
  \\ `?a2. find_code dest a t'.code = SOME (x0,a2) /\
           [x1] = remove_ticks [a2]` by
   (Cases_on `dest` \\ fs [state_rel_def,find_code_def] \\ rveq \\ fs []
    \\ every_case_tac \\ fs [lookup_map] \\ rveq \\ fs []
    \\ rveq \\ fs [])
  \\ fs [] \\ disch_then drule \\ strip_tac
  \\ ntac 2 (pop_assum mp_tac)
  \\ drule evaluate_add_clock \\ fs [inc_clock_def]
  \\ disch_then (qspec_then `ticks+ck'` assume_tac)
  \\ rw [] \\ qexists_tac `ticks + ck+ck'` \\ fs [dec_clock_def]
  \\ qsuff_tac `t'.clock <> 0` \\ rpt strip_tac \\ fs []
  \\ fs [state_rel_def]);

val evaluate_remove_ticks_thm =
  evaluate_remove_ticks
  |> SIMP_RULE std_ss []
  |> Q.SPEC `[Call 0 (SOME start) []]`
  |> SIMP_RULE std_ss [remove_ticks_def];

val remove_ticks_cc_def = Define `
  remove_ticks_cc cc =
    (λcfg prog'. cc cfg (MAP (I ## I ## (λx. HD (remove_ticks [x]))) prog'))`;

val remove_ticks_co_def = Define `
  remove_ticks_co =
    (I ## MAP (I ## I ## (λx. HD (remove_ticks [x]))))`;

val evaluate_compile_prog = Q.store_thm ("evaluate_compile_prog",
  `evaluate ([Call 0 (SOME start) []], [],
             initial_state ffi0 (map
                (I ## (λx. HD (remove_ticks [x]))) prog)
                (remove_ticks_co ∘ co) cc k) = (r, s) ⇒
   ∃ck (s2:('c,'ffi) bvlSem$state).
     evaluate
      ([Call 0 (SOME start) []], [],
        initial_state ffi0 prog co (remove_ticks_cc cc) (k + ck)) = (r, s2) ∧
     s2.ffi = s.ffi`,
  strip_tac \\ fs [remove_ticks_co_def,remove_ticks_cc_def]
  \\ drule (ONCE_REWRITE_RULE [CONJ_COMM]
             (REWRITE_RULE [CONJ_ASSOC] evaluate_remove_ticks_thm))
  \\ disch_then (qspec_then `initial_state ffi0 prog co
        (λcfg prog'. cc cfg (MAP (I ## I ## (λx. HD (remove_ticks [x]))) prog'))
            k` mp_tac)
  \\ impl_tac THEN1 fs [state_rel_def]
  \\ strip_tac \\ fs []
  \\ qexists_tac `ck` \\ fs [state_rel_def]);

val FST_EQ_LEMMA = prove(
  ``FST x = y <=> ?y1. x = (y,y1)``,
  Cases_on `x` \\ fs []);

val compile_prog_semantics = Q.store_thm ("compile_prog_semantics",
  `semantics ffi (map (I ## (λx. HD (remove_ticks [x]))) prog)
                 (remove_ticks_co ∘ co)
                 cc start =
   semantics (ffi:'b ffi_state) prog co (remove_ticks_cc cc) start`,
  simp [Once semantics_def]
  \\ IF_CASES_TAC \\ fs []
  THEN1
   (simp [semantics_def] \\ IF_CASES_TAC \\ fs [FST_EQ_LEMMA]
    \\ drule evaluate_compile_prog \\ metis_tac [])
  \\ DEEP_INTRO_TAC some_intro \\ simp []
  \\ conj_tac
  >-
   (gen_tac \\ strip_tac \\ rveq \\ simp []
    \\ simp [semantics_def]
    \\ IF_CASES_TAC \\ fs []
    >-
      (first_assum (subterm (fn tm => Cases_on`^(assert(has_pair_type)tm)`) o concl)
      \\ drule evaluate_add_clock
      \\ impl_tac >- fs []
      \\ strip_tac
      \\ qpat_x_assum `evaluate (_,_,_ _ (_ prog) _ _ _) = _` kall_tac
      \\ last_assum (qspec_then `k'` mp_tac)
      \\ (fn g => subterm (fn tm => Cases_on`^(assert(has_pair_type)tm)`) (#2 g) g )
      \\ drule (GEN_ALL evaluate_compile_prog) \\ simp []
      \\ strip_tac
      \\ first_x_assum (qspec_then `ck` mp_tac)
      \\ simp [inc_clock_def]
      \\ rw[] \\ fs [])
    \\ DEEP_INTRO_TAC some_intro \\ simp []
    \\ conj_tac
    >-
     (gen_tac \\ strip_tac \\ rveq \\ fs []
      \\ qabbrev_tac `opts = (map (I ## (λx. HD (remove_ticks [x]))) prog)`
      \\ qmatch_assum_abbrev_tac `bvlSem$evaluate (opts1,[],sopt1) = _`
      \\ qmatch_assum_abbrev_tac `bvlSem$evaluate (exps1,[],st1) = (r,s)`
      \\ qspecl_then [`opts1`,`[]`,`sopt1`] mp_tac
           evaluate_add_to_clock_io_events_mono
      \\ qspecl_then [`exps1`,`[]`,`st1`] mp_tac
           evaluate_add_to_clock_io_events_mono
      \\ simp [inc_clock_def, Abbr`sopt1`, Abbr`st1`]
      \\ ntac 2 strip_tac
      \\ Cases_on `s.ffi.final_event` \\ fs []
      >-
        (Cases_on `s'.ffi.final_event` \\ fs []
        >-
          (unabbrev_all_tac
          \\ drule (GEN_ALL evaluate_compile_prog) \\ simp []
          \\ strip_tac
          \\ drule evaluate_add_clock
          \\ impl_tac
          >- (every_case_tac \\ fs [])
          \\ rveq
          \\ disch_then (qspec_then `k'` mp_tac) \\ simp [inc_clock_def]
          \\ qpat_x_assum `evaluate _ = _` kall_tac
          \\ drule evaluate_add_clock
          \\ impl_tac
          >- (spose_not_then strip_assume_tac \\ fs [evaluate_def])
          \\ disch_then (qspec_then `ck+k` mp_tac) \\ simp [inc_clock_def]
          \\ ntac 2 strip_tac \\ rveq \\ fs []
          \\ fs [state_component_equality, state_rel_def])
        \\ qpat_x_assum `∀extra._` mp_tac
        \\ first_x_assum (qspec_then `k'` assume_tac)
        \\ first_assum (subterm
             (fn tm => Cases_on`^(assert has_pair_type tm)`) o concl)
        \\ strip_tac \\ fs []
        \\ unabbrev_all_tac
        \\ drule (GEN_ALL evaluate_compile_prog)
        \\ strip_tac
        \\ qhdtm_x_assum `evaluate` mp_tac
        \\ imp_res_tac evaluate_add_clock
        \\ pop_assum mp_tac
        \\ ntac 2 (pop_assum kall_tac)
        \\ impl_tac
        >- (strip_tac \\ fs [])
        \\ disch_then (qspec_then `k'` mp_tac) \\ simp [inc_clock_def]
        \\ first_x_assum (qspec_then `ck + k` mp_tac) \\ fs []
        \\ ntac 3 strip_tac
        \\ fs [state_rel_def] \\ rveq)
      \\ qpat_x_assum `∀extra._` mp_tac
      \\ first_x_assum (qspec_then `k'` assume_tac)
      \\ first_assum (subterm (fn tm =>
            Cases_on`^(assert has_pair_type tm)`) o concl)
      \\ fs []
      \\ unabbrev_all_tac
      \\ strip_tac
      \\ drule (GEN_ALL evaluate_compile_prog)
      \\ strip_tac \\ rveq \\ fs []
      \\ reverse (Cases_on `s'.ffi.final_event`) \\ fs [] \\ rfs []
      >-
        (first_x_assum (qspec_then `ck + k` mp_tac)
        \\ fs [ADD1]
        \\ strip_tac \\ fs [state_rel_def] \\ rfs [])
      \\ qhdtm_x_assum `evaluate` mp_tac
      \\ imp_res_tac evaluate_add_clock
      \\ pop_assum kall_tac
      \\ pop_assum mp_tac
      \\ impl_tac
      >- (strip_tac \\ fs [])
      \\ disch_then (qspec_then `ck + k` mp_tac)
      \\ simp [inc_clock_def]
      \\ rpt strip_tac \\ rveq
      \\ CCONTR_TAC \\ fs []
      \\ rveq \\ fs [] \\ rfs [])
    \\ qmatch_assum_abbrev_tac `bvlSem$evaluate (exps2,[],st2) = _`
    \\ qspecl_then [`exps2`,`[]`,`st2`] mp_tac evaluate_add_to_clock_io_events_mono
    \\ simp [inc_clock_def, Abbr`st2`]
    \\ disch_then (qspec_then `0` strip_assume_tac)
    \\ first_assum (subterm (fn tm => Cases_on`^(assert(has_pair_type)tm)`) o concl)
    \\ unabbrev_all_tac
    \\ drule (GEN_ALL evaluate_compile_prog)
    \\ strip_tac
    \\ asm_exists_tac \\ fs []
    \\ every_case_tac \\ fs [] \\ rveq \\ fs [])
  \\ strip_tac
  \\ simp [semantics_def]
  \\ IF_CASES_TAC \\ fs []
  >-
    (last_x_assum (qspec_then `k` assume_tac) \\ rfs []
    \\ first_assum (qspec_then `e` assume_tac)
    \\ fs [] \\ rfs []
    \\ qmatch_assum_abbrev_tac `FST q ≠ _`
    \\ Cases_on `q` \\ fs [markerTheory.Abbrev_def]
    \\ pop_assum (assume_tac o SYM)
    \\ drule (GEN_ALL evaluate_compile_prog)
    \\ simp []
    \\ spose_not_then strip_assume_tac
    \\ qmatch_assum_abbrev_tac `FST q = _`
    \\ Cases_on `q` \\ fs [markerTheory.Abbrev_def]
    \\ pop_assum (assume_tac o SYM)
    \\ imp_res_tac evaluate_add_clock \\ rfs []
    \\ first_x_assum (qspec_then `ck` mp_tac)
    \\ simp [inc_clock_def])
  \\ DEEP_INTRO_TAC some_intro \\ simp []
  \\ conj_tac
  >-
    (spose_not_then assume_tac \\ rw []
    \\ fsrw_tac [QUANT_INST_ss[pair_default_qp]] []
    \\ last_assum (qspec_then `k` mp_tac)
    \\ (fn g => subterm (fn tm => Cases_on`^(assert (can dest_prod o type_of) tm)` g) (#2 g))
    \\ strip_tac
    \\ drule (GEN_ALL evaluate_compile_prog)
    \\ strip_tac
    \\ qmatch_assum_rename_tac `evaluate (_,[],_ k) = (_,rr)`
    \\ reverse (Cases_on `rr.ffi.final_event`)
    >-
      (first_x_assum
        (qspecl_then
          [`k`, `FFI_outcome(THE rr.ffi.final_event)`] mp_tac)
      \\ simp [])
    \\ qpat_x_assum `∀x y. ¬z` mp_tac \\ simp []
    \\ qexists_tac `k` \\ simp []
    \\ reverse (Cases_on `s.ffi.final_event`) \\ fs []
    >-
      (qhdtm_x_assum `evaluate` mp_tac
      \\ qmatch_assum_abbrev_tac `bvlSem$evaluate (opts1,[],os1) = (r,_)`
      \\ qspecl_then [`opts1`,`[]`,`os1`] mp_tac evaluate_add_to_clock_io_events_mono
      \\ disch_then (qspec_then `ck` mp_tac)
      \\ fs [ADD1, inc_clock_def, Abbr`os1`]
      \\ rpt strip_tac \\ fs []
      \\ fs [state_rel_def] \\ rfs [])
    \\ qhdtm_x_assum `evaluate` mp_tac
    \\ imp_res_tac evaluate_add_clock
    \\ pop_assum mp_tac
    \\ impl_tac
    >- (strip_tac \\ fs [])
    \\ disch_then (qspec_then `ck` mp_tac)
    \\ simp [inc_clock_def]
    \\ fs [ADD1]
    \\ rpt strip_tac \\ rveq \\ fs [])
  \\ strip_tac
  \\ qmatch_abbrev_tac `build_lprefix_lub l1 = build_lprefix_lub l2`
  \\ `(lprefix_chain l1 ∧ lprefix_chain l2) ∧ equiv_lprefix_chain l1 l2`
     suffices_by metis_tac [build_lprefix_lub_thm,
                            lprefix_lub_new_chain,
                            unique_lprefix_lub]
  \\ conj_asm1_tac
  >-
    (unabbrev_all_tac
    \\ conj_tac
    \\ Ho_Rewrite.ONCE_REWRITE_TAC [GSYM o_DEF]
    \\ REWRITE_TAC [IMAGE_COMPOSE]
    \\ match_mp_tac prefix_chain_lprefix_chain
    \\ simp [prefix_chain_def, PULL_EXISTS]
    \\ qx_genl_tac [`k1`,`k2`]
    \\ qspecl_then [`k1`,`k2`] mp_tac LESS_EQ_CASES
    \\ metis_tac [
         LESS_EQ_EXISTS,
         bviPropsTheory.initial_state_with_simp,
         bvlPropsTheory.initial_state_with_simp,
         bviPropsTheory.evaluate_add_to_clock_io_events_mono
           |> CONV_RULE(RESORT_FORALL_CONV(sort_vars["s"]))
           |> Q.SPEC`s with clock := k`
           |> SIMP_RULE (srw_ss())[bviPropsTheory.inc_clock_def],
         bvlPropsTheory.evaluate_add_to_clock_io_events_mono
           |> CONV_RULE(RESORT_FORALL_CONV(sort_vars["s"]))
           |> Q.SPEC`s with clock := k`
           |> SIMP_RULE (srw_ss())[bvlPropsTheory.inc_clock_def]])
  \\ simp [equiv_lprefix_chain_thm]
  \\ unabbrev_all_tac \\ simp [PULL_EXISTS]
  \\ simp [LNTH_fromList, PULL_EXISTS, GSYM FORALL_AND_THM]
  \\ rpt gen_tac
  \\ Cases_on `(evaluate
         ([Call 0 (SOME start) []],[],
          initial_state ffi
            (map (I ## (λx. HD (remove_ticks [x]))) prog)
            (remove_ticks_co ∘ co) cc k))`
  \\ drule (GEN_ALL evaluate_compile_prog)
  \\ strip_tac \\ fs []
  \\ conj_tac \\ rw []
  >- (qexists_tac `ck + k`
      \\ fs [])
  \\ qexists_tac `k` \\ fs []
  \\ qmatch_assum_abbrev_tac `_ < (LENGTH (_ ffi1))`
  \\ `ffi1.io_events ≼ r.ffi.io_events` by
    (qunabbrev_tac `ffi1`
    \\ metis_tac [
       initial_state_with_simp, evaluate_add_to_clock_io_events_mono
         |> CONV_RULE(RESORT_FORALL_CONV(sort_vars["s"]))
         |> Q.SPEC`s with clock := k`
         |> SIMP_RULE(srw_ss())[inc_clock_def],
       SND,ADD_SYM])
  \\ fs [IS_PREFIX_APPEND]
  \\ simp [EL_APPEND1]);

val remove_ticks_CONS = prove(
  ``!xs x. remove_ticks (x::xs) =
           HD (remove_ticks [x]) :: remove_ticks xs``,
  Cases \\ fs [remove_ticks_def]);

(* inline implementation *)

val tick_inline_def = tDefine "tick_inline" `
  (tick_inline cs [] = []) /\
  (tick_inline cs (x::y::xs) =
     HD (tick_inline cs [x]) :: tick_inline cs (y::xs)) /\
  (tick_inline cs [Var v] = [Var v]) /\
  (tick_inline cs [If x1 x2 x3] =
     [If (HD (tick_inline cs [x1]))
         (HD (tick_inline cs [x2]))
         (HD (tick_inline cs [x3]))]) /\
  (tick_inline cs [Let xs x2] =
     [Let (tick_inline cs xs)
           (HD (tick_inline cs [x2]))]) /\
  (tick_inline cs [Raise x1] =
     [Raise (HD (tick_inline cs [x1]))]) /\
  (tick_inline cs [Handle x1 x2] =
     [Handle (HD (tick_inline cs [x1]))
              (HD (tick_inline cs [x2]))]) /\
  (tick_inline cs [Op op xs] =
     [Op op (tick_inline cs xs)]) /\
  (tick_inline cs [Tick x] =
     [Tick (HD (tick_inline cs [x]))]) /\
  (tick_inline cs [Call ticks dest xs] =
     case dest of NONE => [Call ticks dest (tick_inline cs xs)] | SOME n =>
     case lookup n cs of
     | NONE => [Call ticks dest (tick_inline cs xs)]
     | SOME (arity,code) => [Let (tick_inline cs xs) (mk_tick (SUC ticks) code)])`
  (WF_REL_TAC `measure (exp1_size o SND)`);

val tick_inline_ind = theorem"tick_inline_ind";

val tick_inline_all_def = Define `
  (tick_inline_all limit cs [] aux = (cs,REVERSE aux)) /\
  (tick_inline_all limit cs ((n,arity:num,e1)::xs) aux =
     let e2 = HD (tick_inline cs [e1]) in
     let cs2 = if must_inline n limit e2 then insert n (arity,e2) cs else cs in
       tick_inline_all limit cs2 xs ((n,arity,e2)::aux))`;

val tick_compile_prog_def = Define `
  tick_compile_prog limit cs prog = tick_inline_all limit cs prog []`

val LENGTH_tick_inline = Q.store_thm("LENGTH_tick_inline",
  `!cs xs. LENGTH (tick_inline cs xs) = LENGTH xs`,
  recInduct tick_inline_ind \\ REPEAT STRIP_TAC
  \\ fs [Once tick_inline_def,LET_DEF] \\ rw [] \\ every_case_tac \\ fs []);

val HD_tick_inline = Q.store_thm("HD_tick_inline[simp]",
  `[HD (tick_inline cs [x])] = tick_inline cs [x]`,
  `LENGTH (tick_inline cs [x]) = LENGTH [x]` by SRW_TAC [] [LENGTH_tick_inline]
  \\ Cases_on `tick_inline cs [x]` \\ FULL_SIMP_TAC std_ss [LENGTH]
  \\ Cases_on `t` \\ FULL_SIMP_TAC std_ss [LENGTH,HD] \\ `F` by DECIDE_TAC);

val (exp_rel_rules, exp_rel_ind, exp_rel_cases) = Hol_reln `
  (!cs v. exp_rel (cs: (num # bvl$exp) num_map) [bvl$Var v] [bvl$Var v]) /\
  (!cs. exp_rel cs [] []) /\
  (!cs x x1 xs y y1 ys.
     exp_rel cs [x] [y] /\
     exp_rel cs (x1::xs) (y1::ys) ==>
     exp_rel cs (x::x1::xs) (y::y1::ys)) /\
  (exp_rel cs [x1] [y1] /\
   exp_rel cs [x2] [y2] /\
   exp_rel cs [x3] [y3]==>
   exp_rel cs [If x1 x2 x3] [If y1 y2 y3]) /\
  (exp_rel cs xs ys /\
   exp_rel cs [x] [y] ==>
   exp_rel cs [Let xs x] [Let ys y]) /\
  (exp_rel cs [x1] [y1] /\
   exp_rel cs [x2] [y2] ==>
   exp_rel cs [Handle x1 x2] [Handle y1 y2]) /\
  (exp_rel cs [x] [y] ==>
   exp_rel cs [Raise x] [Raise y]) /\
  (exp_rel cs [x] [y] ==>
   exp_rel cs [Tick x] [Tick y]) /\
  (exp_rel cs xs ys ==>
   exp_rel cs [Op op xs] [Op op ys]) /\
  (exp_rel cs xs ys ==>
   exp_rel cs [Call ticks dest xs] [Call ticks dest ys]) /\
  (exp_rel cs xs ys /\ lookup n cs = SOME (LENGTH xs, x) /\
   exp_rel cs [x] [y] ==>
   exp_rel cs [Call ticks (SOME n) xs]
              [Let ys (mk_tick (SUC ticks) y)])`;

val in_cc_def = Define `
  in_cc limit cc =
    (λ(cs,cfg) prog.
        let (cs1,prog1) = tick_compile_prog limit cs prog in
          case cc cfg prog1 of
          | NONE => NONE
          | SOME (code,data,cfg1) => SOME (code,data,(cs1,cfg1)))`

val in_state_rel_def = Define `
  in_state_rel limit s t <=>
    t.globals = s.globals ∧
    t.refs = s.refs ∧
    t.clock = s.clock ∧
    t.ffi = s.ffi ∧
    t.compile_oracle = (λn.
      let ((cs,cfg),progs) = s.compile_oracle n in
      let (cs1,progs) = tick_compile_prog limit cs progs in
        (cfg,progs)) ∧
    (!n. let ((cs,cfg),progs) = s.compile_oracle n in
         let (cs1,progs) = tick_compile_prog limit cs progs in
           FST (FST (s.compile_oracle (n+1))) = cs1) /\
    subspt (FST (FST (s.compile_oracle 0))) t.code /\
    s.compile = in_cc limit t.compile /\
    domain t.code = domain s.code /\
    (!k arity exp.
       lookup k s.code = SOME (arity,exp) ==>
       ?exp2. lookup k t.code = SOME (arity,exp2) /\
              exp_rel s.code [exp] [exp2])`;

val subspt_exp_rel = store_thm("subspt_exp_rel",
  ``!s1 s2 xs ys. subspt s1 s2 /\ exp_rel s1 xs ys ==> exp_rel s2 xs ys``,
  qsuff_tac `!s1 xs ys. exp_rel s1 xs ys ==> !s2. subspt s1 s2 ==> exp_rel s2 xs ys`
  THEN1 metis_tac []
  \\ ho_match_mp_tac exp_rel_ind \\ rw []
  \\ once_rewrite_tac [exp_rel_cases] \\ fs []
  \\ fs [subspt_def,domain_lookup,PULL_EXISTS]
  \\ res_tac \\ fs [] \\ metis_tac []);

val tick_compile_prog_IMP = prove(
  ``tick_compile_prog limit q0 ((k,prog)::t) = (cs1,prog1) ==>
    ?p1 vs. prog1 = (k,p1)::vs /\ MAP FST vs = MAP FST t``,
  cheat);

val in_do_app_lemma = prove(
  ``in_state_rel limit s1 t1 ==>
    case do_app op a s1 of
    | Rerr err => do_app op a t1 = Rerr err
    | Rval (v,s2) => ?t2. in_state_rel limit s2 t2 /\
                          do_app op a t1 = Rval (v,t2)``,
  Cases_on `op = Install`
  THEN1
   (rw [] \\ fs [do_app_def]
    \\ every_case_tac \\ fs []
    \\ fs [case_eq_thms,UNCURRY,do_install_def]
    \\ rveq \\ fs [PULL_EXISTS]
    \\ fs [SWAP_REVERSE_SYM] \\ rveq \\ fs []
    \\ fs [state_rel_def] \\ rveq \\ fs []
    \\ fs [state_component_equality,in_state_rel_def]
    THEN1
     (fs [shift_seq_def,o_DEF] \\ rfs []
      \\ Cases_on `s1.compile_oracle 0` \\ fs []
      \\ Cases_on `r` \\ fs [] \\ Cases_on `h` \\ fs [] \\ rveq \\ fs []
      \\ PairCases_on `q` \\ fs [domain_union]
      \\ CONV_TAC (DEPTH_CONV PairRules.PBETA_CONV)
      \\ fs [domain_fromAList,in_cc_def]
      \\ pairarg_tac \\ fs [case_eq_thms] \\ rveq \\ fs []
      \\ qpat_x_assum `_ = FST _` (assume_tac o GSYM) \\ fs []
      \\ drule tick_compile_prog_IMP \\ strip_tac \\ fs []
      \\ rveq \\ fs []
      \\ qpat_abbrev_tac `in1 = (k,prog)::t`
      \\ qpat_abbrev_tac `in2 = (k,p1)::vs`
      \\ fs [lookup_union,case_eq_thms]
      \\ reverse (rw [])
      THEN1
       (first_x_assum drule \\ strip_tac \\ fs []
        \\ match_mp_tac subspt_exp_rel \\ metis_tac [subspt_union])
      THEN1
       (reverse (Cases_on `lookup k' t1.code`) \\ fs []
        THEN1 (fs [domain_lookup,EXTENSION] \\ metis_tac [NOT_SOME_NONE])
        \\ fs [lookup_fromAList]
        \\ cheat (* probably true *))
      \\ cheat (* needs assumption about oracle names *))
    \\ CONV_TAC (DEPTH_CONV PairRules.PBETA_CONV) \\ fs []
    THEN1 fs [tick_compile_prog_def,tick_inline_all_def]
    \\ disj2_tac \\ rfs [in_cc_def]
    \\ rpt (pairarg_tac \\ fs []) \\ fs [case_eq_thms]
    \\ TRY (PairCases_on `v6`) \\ fs [PULL_EXISTS]
    \\ drule tick_compile_prog_IMP \\ strip_tac \\ fs [] \\ rveq \\ fs []
    \\ CCONTR_TAC \\ fs [] \\ rveq \\ fs []
    \\ fs [shift_seq_def]

    \\ cheat (* almost true *))
  \\ strip_tac \\ reverse (Cases_on `do_app op a s1`) \\ fs []
  \\ `t1 = t1 with <| globals := s1.globals ;
                               refs := s1.refs ;
                               clock := s1.clock ;
                               ffi := s1.ffi |>` by
         fs [in_state_rel_def,state_component_equality]
  \\ pop_assum (fn th => once_rewrite_tac [th])
  THEN1 (match_mp_tac do_app_Rerr_swap \\ fs [in_state_rel_def])
  \\ rename1 `_ = Rval x`
  \\ PairCases_on `x` \\ fs []
  \\ drule (do_app_Rval_swap |> GEN_ALL
      |> INST_TYPE [alpha|->gamma,beta|->delta,gamma|->alpha,delta|->beta])
  \\ fs []
  \\ disch_then (qspec_then `t1` mp_tac)
  \\ impl_tac THEN1 fs [in_state_rel_def]
  \\ fs [] \\ disch_then kall_tac
  \\ fs [in_state_rel_def]
  \\ imp_res_tac do_app_const \\ fs []);

val evaluate_inline = store_thm("evaluate_inline",
  ``!es env s1 res t1 s2 es2.
      in_state_rel limit s1 t1 /\ exp_rel s1.code es es2 /\
      evaluate (es,env,s1) = (res,s2) /\ res ≠ Rerr (Rabort Rtype_error) ==>
      ?t2. evaluate (es2,env,t1) = (res,t2) /\
           in_state_rel limit s2 t2``,
  recInduct evaluate_ind \\ rw [] \\ fs []
  \\ fs [evaluate_def] \\ rveq \\ fs []
  \\ qpat_x_assum `exp_rel _ _ _` mp_tac
  \\ once_rewrite_tac [exp_rel_cases] \\ fs [] \\ rw []
  THEN1
   (fs [evaluate_def])
  THEN1
   (fs [case_eq_thms] \\ rveq \\ fs []
    \\ first_x_assum drule
    \\ disch_then drule \\ strip_tac
    \\ fs [evaluate_def]
    \\ first_x_assum drule
    \\ imp_res_tac evaluate_mono
    \\ drule subspt_exp_rel \\ disch_then drule \\ rw []
    \\ pop_assum drule \\ rw [] \\ fs [])
  THEN1
   (fs [evaluate_def] \\ rw [] \\ fs [])
  THEN1
   (fs [case_eq_thms] \\ rveq \\ fs []
    \\ rpt (qpat_x_assum `_ = bvlSem$evaluate _` (assume_tac o GSYM)) \\ fs []
    \\ first_x_assum drule
    \\ disch_then drule \\ strip_tac
    \\ fs [evaluate_def]
    \\ first_x_assum drule
    \\ imp_res_tac evaluate_mono
    \\ imp_res_tac subspt_exp_rel
    \\ metis_tac [])
  THEN1
   (fs [case_eq_thms] \\ rveq \\ fs []
    \\ first_x_assum drule
    \\ disch_then drule \\ strip_tac
    \\ fs [evaluate_def]
    \\ first_x_assum drule
    \\ imp_res_tac evaluate_mono
    \\ drule subspt_exp_rel \\ disch_then drule \\ rw []
    \\ pop_assum drule \\ rw [] \\ fs [])
  THEN1
   (fs [case_eq_thms] \\ rveq \\ fs []
    \\ first_x_assum drule
    \\ disch_then drule \\ strip_tac
    \\ fs [evaluate_def])
  THEN1
   (fs [case_eq_thms] \\ rveq \\ fs []
    \\ first_x_assum drule
    \\ disch_then drule \\ strip_tac
    \\ fs [evaluate_def]
    \\ first_x_assum drule
    \\ imp_res_tac evaluate_mono
    \\ drule subspt_exp_rel \\ disch_then drule \\ rw []
    \\ pop_assum drule \\ rw [] \\ fs [])
  THEN1
   (fs [case_eq_thms] \\ rveq \\ fs []
    \\ first_x_assum drule
    \\ disch_then drule \\ strip_tac
    \\ fs [evaluate_def]
    \\ drule (Q.GEN `a` in_do_app_lemma)
    \\ disch_then (qspec_then `REVERSE vs` mp_tac) \\ fs []
    \\ strip_tac \\ fs [])
  THEN1
   (`s.clock = t1.clock` by fs [in_state_rel_def]
    \\ fs [case_eq_thms] \\ rveq
    \\ fs [evaluate_def]
    \\ rpt (qpat_x_assum `_ = bvlSem$evaluate _` (assume_tac o GSYM)) \\ fs []
    \\ `in_state_rel limit (dec_clock 1 s) (dec_clock 1 t1)`
          by fs [in_state_rel_def,dec_clock_def]
    \\ first_x_assum drule
    \\ disch_then drule \\ strip_tac
    \\ fs [evaluate_def])
  THEN1
   (reverse (fs [case_eq_thms] \\ rveq \\ fs [])
    \\ first_x_assum drule
    \\ disch_then drule \\ strip_tac
    \\ fs [evaluate_def]
    \\ rpt (qpat_x_assum `_ = bvlSem$evaluate _` (assume_tac o GSYM)) \\ fs []
    \\ `?exp2. find_code dest vs t2.code = SOME (args,exp2) /\
               exp_rel s.code [exp] [exp2]` by
     (Cases_on `dest` \\ fs [find_code_def,case_eq_thms]
      \\ fs [in_state_rel_def] \\ rveq
      \\ qpat_x_assum `!x._` drule
      \\ rw [] \\ fs [])
    \\ `s.clock = t2.clock` by fs [in_state_rel_def] \\ fs []
    \\ TRY (fs [in_state_rel_def] \\ NO_TAC)
    \\ `in_state_rel limit (dec_clock (ticks + 1) s) (dec_clock (ticks + 1) t2)`
              by fs [in_state_rel_def,dec_clock_def]
    \\ first_x_assum drule
    \\ disch_then match_mp_tac \\ fs [])
  \\ reverse (fs [case_eq_thms] \\ rveq \\ fs [])
  \\ first_x_assum drule
  \\ disch_then drule \\ strip_tac
  \\ `t2.clock = s.clock` by fs [in_state_rel_def]
  \\ fs [evaluate_def,evaluate_mk_tick]
  \\ TRY (fs [in_state_rel_def] \\ NO_TAC)
  \\ fs [find_code_def,case_eq_thms] \\ rveq
  \\ `in_state_rel limit (dec_clock (ticks + 1) s) (dec_clock (ticks + 1) t2)`
              by fs [in_state_rel_def,dec_clock_def]
  \\ first_x_assum drule
  \\ imp_res_tac evaluate_mono
  \\ `lookup n s.code = lookup n s1.code` by fs [subspt_def,domain_lookup]
  \\ fs [] \\ rveq
  \\ `exp_rel s.code [exp] [y]` by imp_res_tac subspt_exp_rel
  \\ disch_then drule
  \\ rpt (qpat_x_assum `_ = bvlSem$evaluate _` (assume_tac o GSYM)) \\ fs []
  \\ strip_tac \\ fs [ADD1]
  \\ `FST (evaluate ([y],args,dec_clock (ticks + 1) t2)) <>
      Rerr (Rabort Rtype_error)` by fs []
  \\ drule evaluate_expand_env \\ fs []);

(* let_op *)

val let_state_rel_def = Define `
  let_state_rel (s:('c,'ffi) bvlSem$state) (t:('c,'ffi) bvlSem$state) <=>
    t = s with <| code := map (I ## let_op_sing) s.code
                ; compile := t.compile
                ; compile_oracle := (I ##
      MAP (I ## I ## let_op_sing)) o s.compile_oracle |> /\
    s.compile = \cfg prog. t.compile cfg (MAP (I ## I ## let_op_sing) prog)`

val let_state_rel_alt = let_state_rel_def

val let_state_rel_def = let_state_rel_def
  |> SIMP_RULE (srw_ss()) [state_component_equality,GSYM CONJ_ASSOC];

val HD_let_op = store_thm("HD_let_op[simp]",
  ``[HD (let_op [x])] = let_op [x]``,
  Cases_on `x` \\ simp_tac std_ss [let_op_def] \\ fs []
  \\ CASE_TAC \\ fs []);

val let_op_sing_thm = prove(
  ``let_op_sing x = HD (let_op [x])``,
  fs [let_op_sing_def]
  \\ once_rewrite_tac [GSYM HD_let_op] \\ fs []);

val var_list_IMP_evaluate = prove(
  ``!a2 a1 l xs s.
      var_list (LENGTH a1) l xs /\ LENGTH (xs:bvl$exp list) = LENGTH a2 ==>
      evaluate (l,a1++a2++env,s) = (Rval a2,s)``,
  Induct THEN1
   (fs [APPEND_NIL,var_list_def]
    \\ Cases_on `l` \\ fs [var_list_def,evaluate_def]
    \\ Cases_on `h` \\ fs [var_list_def,evaluate_def])
  \\ Cases_on `xs` \\ fs [LENGTH]
  \\ Cases_on `l` \\ fs [var_list_def]
  \\ Cases_on `h'` \\ fs [var_list_def]
  \\ once_rewrite_tac [evaluate_CONS]
  \\ fs [evaluate_def,EL_LENGTH_APPEND] \\ rw []
  \\ simp_tac std_ss [GSYM APPEND_ASSOC,APPEND]
  \\ first_x_assum (qspec_then `a1 ++ [h']` mp_tac)
  \\ fs [] \\ rw [] \\ res_tac
  \\ full_simp_tac std_ss [GSYM APPEND_ASSOC,APPEND]
  \\ fs [EL_LENGTH_APPEND]);

val var_list_IMP_evaluate = prove(
  ``var_list 0 l xs /\ LENGTH (xs:bvl$exp list) = LENGTH a ==>
    evaluate (l,a++env,s) = (Rval a,s)``,
  rw []
  \\ match_mp_tac (Q.SPECL [`xs`,`[]`] var_list_IMP_evaluate
       |> SIMP_RULE std_ss [APPEND,LENGTH])
  \\ asm_exists_tac \\ fs []);

val LENGTH_let_op = store_thm("LENGTH_let_op",
  ``!xs. LENGTH (let_op xs) = LENGTH xs``,
  ho_match_mp_tac let_op_ind \\ rw [let_op_def]
  \\ CASE_TAC \\ fs []);

val do_app_lemma = prove(
  ``let_state_rel s1 t1 ==>
    case do_app op a s1 of
    | Rerr err => do_app op a t1 = Rerr err
    | Rval (v,s2) => ?t2. let_state_rel s2 t2 /\ do_app op a t1 = Rval (v,t2)``,
  Cases_on `op = Install` THEN1
   (rw [] \\ fs [do_app_def]
    \\ every_case_tac \\ fs []
    \\ fs [case_eq_thms,UNCURRY,do_install_def]
    \\ rveq \\ fs [PULL_EXISTS]
    \\ fs [SWAP_REVERSE_SYM] \\ rveq \\ fs []
    \\ fs [let_state_rel_def] \\ rveq \\ fs []
    \\ fs [state_component_equality]
    THEN1
     (fs [shift_seq_def,o_DEF] \\ rfs []
      \\ Cases_on `s1.compile_oracle 0` \\ fs []
      \\ Cases_on `r` \\ fs [] \\ Cases_on `h` \\ fs [] \\ rveq \\ fs []
      \\ fs [map_union] \\ AP_TERM_TAC
      \\ fs [map_fromAList] \\ AP_TERM_TAC \\ fs []
      \\ rpt (AP_THM_TAC ORELSE AP_TERM_TAC)
      \\ fs [FUN_EQ_THM,FORALL_PROD])
    \\ CCONTR_TAC \\ fs [] \\ rfs [FORALL_PROD,shift_seq_def])
  \\ strip_tac \\ Cases_on `do_app op a s1` \\ fs []
  THEN1
   (rename1 `_ = Rval aa`
    \\ PairCases_on `aa`
    \\ drule (Q.GENL [`c`,`cc`,`co`] do_app_with_code) \\ fs []
    \\ fs [let_state_rel_alt]
    \\ disch_then (qspecl_then [`map (I ## let_op_sing) s1.code`,
        `t1.compile`,`(I ## MAP (I ## I ## let_op_sing)) ∘
          s1.compile_oracle`] mp_tac)
    \\ qpat_x_assum `t1 = _` (assume_tac o GSYM) \\ fs []
    \\ impl_tac THEN1 fs [domain_map]
    \\ strip_tac \\ fs []
    \\ qpat_x_assum `_ = t1` (assume_tac o GSYM) \\ fs []
    \\ rw [] \\ fs [state_component_equality]
    \\ imp_res_tac do_app_const \\ fs [])
  \\ drule (Q.GENL [`c`,`cc`,`co`] do_app_with_code_err_not_Install) \\ fs []
  \\ fs [let_state_rel_alt]
  \\ disch_then (qspecl_then [`map (I ## let_op_sing) s1.code`,
      `t1.compile`,`(I ## MAP (I ## I ## let_op_sing)) ∘
        s1.compile_oracle`] mp_tac)
  \\ qpat_x_assum `t1 = _` (assume_tac o GSYM) \\ fs []
  \\ impl_tac THEN1 fs [domain_map] \\ fs []);

val evaluate_let_op = store_thm("evaluate_let_op",
  ``!es env s1 res t1 s2.
      let_state_rel s1 t1 /\
      evaluate (es,env,s1) = (res,s2) /\ res ≠ Rerr (Rabort Rtype_error) ==>
      ?t2. evaluate (let_op es,env,t1) = (res,t2) /\ let_state_rel s2 t2``,
  recInduct evaluate_ind \\ rw [] \\ fs [let_op_def]
  \\ fs [evaluate_def]
  THEN1
   (once_rewrite_tac [evaluate_CONS]
    \\ fs [case_eq_thms] \\ rveq \\ fs [] \\ fs[]
    \\ res_tac \\ fs [])
  THEN1 (rw [] \\ fs [])
  THEN1
   (fs [case_eq_thms] \\ rveq \\ fs [] \\ fs[]
    \\ rpt (qpat_x_assum `_ = bvlSem$evaluate _` (assume_tac o GSYM))
    \\ fs [] \\ res_tac \\ fs [] \\ res_tac \\ fs [])
  THEN1
   (fs [case_eq_thms] \\ rveq \\ fs [] \\ fs[]
    \\ first_x_assum drule \\ rw [] \\ fs []
    THEN1
     (first_x_assum drule \\ rw [] \\ fs []
      \\ TOP_CASE_TAC \\ fs []
      \\ fs [evaluate_def]
      \\ Cases_on `HD (let_op [x2])` \\ fs [dest_op_def] \\ rveq
      \\ drule (GEN_ALL var_list_IMP_evaluate) \\ fs [LENGTH_let_op]
      \\ imp_res_tac evaluate_IMP_LENGTH
      \\ disch_then drule \\ rw []
      \\ rename1 `_ = Op opname l`
      \\ qsuff_tac `let_op [x2] = [Op opname l]`
      THEN1 (rw [] \\ fs [evaluate_def])
      \\ once_rewrite_tac [GSYM HD_let_op] \\ fs [])
    \\ TOP_CASE_TAC \\ fs []
    \\ fs [evaluate_def])
  THEN1
   (fs [case_eq_thms] \\ rveq \\ fs [] \\ fs[]
    \\ rpt (qpat_x_assum `_ = bvlSem$evaluate _` (assume_tac o GSYM))
    \\ fs [] \\ res_tac \\ fs [] \\ res_tac \\ fs [])
  THEN1
   (fs [case_eq_thms] \\ rveq \\ fs [] \\ fs[]
    \\ rpt (qpat_x_assum `_ = bvlSem$evaluate _` (assume_tac o GSYM))
    \\ fs [] \\ res_tac \\ fs [] \\ res_tac \\ fs [])
  THEN1
   (fs [case_eq_thms] \\ rveq \\ fs [] \\ fs[]
    \\ rpt (qpat_x_assum `_ = bvlSem$evaluate _` (assume_tac o GSYM)) \\ fs []
    \\ fs [] \\ res_tac \\ fs [] \\ res_tac \\ fs []
    \\ rveq \\ fs []
    \\ drule (do_app_lemma |> Q.GEN `a` |> Q.SPEC `REVERSE vs`)
    \\ fs [] \\ rw [] \\ fs [])
  THEN1
   (fs [case_eq_thms] \\ rveq \\ fs [] \\ fs[]
    \\ rpt (qpat_x_assum `_ = bvlSem$evaluate _` (assume_tac o GSYM))
    \\ fs [] \\ res_tac \\ fs [] \\ res_tac \\ fs []
    THEN1 (fs [let_state_rel_def])
    \\ `let_state_rel (dec_clock 1 s) (dec_clock 1 t1)`
           by fs [let_state_rel_def,dec_clock_def]
    \\ fs [] \\ res_tac \\ fs [] \\ res_tac \\ fs []
    \\ rveq \\ fs []
    \\ qexists_tac `t2` \\ fs [] \\ fs [let_state_rel_def])
  THEN1
   (fs [case_eq_thms] \\ rveq \\ fs [] \\ fs[]
    \\ rpt (qpat_x_assum `_ = bvlSem$evaluate _` (assume_tac o GSYM))
    \\ fs [] \\ res_tac \\ fs [] \\ res_tac \\ fs [] \\ rveq
    \\ res_tac \\ fs [PULL_EXISTS]
    THEN1
     (qexists_tac `t2' with clock := 0` \\ fs [let_state_rel_def]
      \\ Cases_on `dest` \\ fs [find_code_def]
      \\ fs [case_eq_thms,lookup_map])
    \\ `find_code dest vs t2.code = SOME (args,HD (let_op [exp]))` by
     (Cases_on `dest`
      \\ fs [find_code_def,case_eq_thms,let_state_rel_def,lookup_map]
      \\ fs [let_op_sing_thm])
    \\ fs []
    \\ `let_state_rel (dec_clock (ticks + 1) s) (dec_clock (ticks + 1) t2)`
          by fs [let_state_rel_def,dec_clock_def]
    \\ res_tac \\ fs [] \\ rfs [let_state_rel_def]));

val let_op_cc_def = Define `
  let_op_cc cc =
     (λcfg prog. cc cfg (MAP (I ## I ## let_op_sing) prog))`;

val let_evaluate_compile_prog = Q.store_thm ("evaluate_compile_prog",
  `evaluate ([Call 0 (SOME start) []], [],
             initial_state ffi0 prog co (let_op_cc cc) k) = (r, s) /\
   r <> Rerr (Rabort Rtype_error) ⇒
   ∃ck (s2:('c,'ffi) bvlSem$state).
     evaluate
      ([Call 0 (SOME start) []], [],
        initial_state ffi0 (map (I ## let_op_sing) prog)
          ((I ## MAP (I ## I ## let_op_sing)) o co)
          cc (k + ck)) = (r, s2) ∧
     s2.ffi = s.ffi /\ s.clock = s2.clock`,
  strip_tac \\ fs [let_op_cc_def]
  \\ imp_res_tac evaluate_let_op
  \\ fs [let_op_def]
  \\ qexists_tac `0` \\ fs []
  \\ qmatch_goalsub_abbrev_tac `([_],[],t4)`
  \\ first_x_assum (qspec_then `t4` mp_tac)
  \\ impl_tac \\ rw [] \\ fs []
  \\ fs [let_state_rel_def]
  \\ unabbrev_all_tac \\ fs [initial_state_def]);

val let_evaluate_compile_prog_no_clock = Q.prove(
  `evaluate ([Call 0 (SOME start) []], [],
             initial_state ffi0 prog co (let_op_cc cc) k) = (r, s) /\
   r <> Rerr (Rabort Rtype_error) ⇒
   ∃(s2:('c,'ffi) bvlSem$state).
     evaluate
      ([Call 0 (SOME start) []], [],
        initial_state ffi0 (map (I ## let_op_sing) prog)
          ((I ## MAP (I ## I ## let_op_sing)) o co)
          cc k) = (r, s2) ∧
     s2.ffi = s.ffi /\ s.clock = s2.clock`,
  strip_tac \\ fs [let_op_cc_def]
  \\ imp_res_tac evaluate_let_op
  \\ fs [let_op_def]
  \\ qmatch_goalsub_abbrev_tac `([_],[],t4)`
  \\ first_x_assum (qspec_then `t4` mp_tac)
  \\ impl_tac \\ rw [] \\ fs []
  \\ fs [let_state_rel_def]
  \\ unabbrev_all_tac \\ fs [initial_state_def]);

val semantics_let_op = prove(
  ``semantics ffi prog co (let_op_cc cc) start <> Fail ==>
    semantics ffi (map (I ## let_op_sing) prog)
                  ((I ## MAP (I ## I ## let_op_sing)) o co) cc start =
    semantics (ffi:'b ffi_state) prog co (let_op_cc cc) start``,
  simp [Once semantics_def]
  \\ simp [Once semantics_def, SimpRHS]
  \\ IF_CASES_TAC \\ fs []
  \\ DEEP_INTRO_TAC some_intro \\ simp []
  \\ conj_tac
  >-
   (gen_tac \\ strip_tac \\ rveq \\ simp []
    \\ simp [semantics_def]
    \\ IF_CASES_TAC \\ fs []
    >-
      (first_assum (subterm (fn tm => Cases_on`^(assert(has_pair_type)tm)`) o concl)
      \\ drule evaluate_add_clock
      \\ impl_tac >- fs []
      \\ strip_tac
      \\ qpat_x_assum `evaluate (_,_,_ _ (_ prog) _ _ _) = _` kall_tac
      \\ last_assum (qspec_then `k'` mp_tac)
      \\ (fn g => subterm (fn tm => Cases_on`^(assert(has_pair_type)tm)`) (#2 g) g )
      \\ rw [] \\ fs [] \\ rveq
      \\ CCONTR_TAC
      \\ drule (GEN_ALL let_evaluate_compile_prog) \\ simp []
      \\ strip_tac
      \\ first_x_assum (qspec_then `ck` mp_tac)
      \\ simp [inc_clock_def]
      \\ rw[] \\ fs [])
    \\ DEEP_INTRO_TAC some_intro \\ simp []
    \\ conj_tac
    >-
     (gen_tac \\ strip_tac \\ rveq \\ fs []
      \\ qabbrev_tac `opts = (map (I ## let_op_sing) prog)`
      \\ qmatch_assum_abbrev_tac `bvlSem$evaluate (opts1,[],sopt1) = _`
      \\ qmatch_assum_abbrev_tac `bvlSem$evaluate (exps1,[],st1) = (r,s)`
      \\ qspecl_then [`opts1`,`[]`,`sopt1`] mp_tac
           evaluate_add_to_clock_io_events_mono
      \\ qspecl_then [`exps1`,`[]`,`st1`] mp_tac
           evaluate_add_to_clock_io_events_mono
      \\ simp [inc_clock_def, Abbr`sopt1`, Abbr`st1`]
      \\ ntac 2 strip_tac
      \\ Cases_on `s.ffi.final_event` \\ fs []
      >-
        (Cases_on `s'.ffi.final_event` \\ fs []
        >-
          (unabbrev_all_tac
          \\ drule (GEN_ALL let_evaluate_compile_prog) \\ simp []
          \\ strip_tac
          \\ drule evaluate_add_clock
          \\ impl_tac
          >- (every_case_tac \\ fs [])
          \\ rveq
          \\ disch_then (qspec_then `k'` mp_tac) \\ simp [inc_clock_def]
          \\ qpat_x_assum `evaluate _ = _` kall_tac
          \\ drule evaluate_add_clock
          \\ impl_tac
          >- (spose_not_then strip_assume_tac \\ fs [evaluate_def])
          \\ disch_then (qspec_then `ck+k` mp_tac) \\ simp [inc_clock_def]
          \\ ntac 2 strip_tac \\ rveq \\ fs []
          \\ fs [state_component_equality] \\ rfs [] \\ rfs [])
        \\ qpat_x_assum `∀extra._` mp_tac
        \\ first_x_assum (qspec_then `k'` assume_tac)
        \\ first_assum (subterm
             (fn tm => Cases_on`^(assert has_pair_type tm)`) o concl)
        \\ strip_tac \\ fs []
        \\ unabbrev_all_tac
        \\ drule (GEN_ALL let_evaluate_compile_prog)
        \\ impl_tac
        >- (last_x_assum (qspec_then `k+k'` mp_tac) \\ fs [])
        \\ strip_tac
        \\ qhdtm_x_assum `evaluate` mp_tac
        \\ imp_res_tac evaluate_add_clock
        \\ pop_assum mp_tac
        \\ ntac 2 (pop_assum kall_tac)
        \\ impl_tac
        >- (strip_tac \\ fs [])
        \\ disch_then (qspec_then `k'` mp_tac) \\ simp [inc_clock_def]
        \\ first_x_assum (qspec_then `ck + k` mp_tac) \\ fs []
        \\ ntac 3 strip_tac
        \\ fs [let_state_rel_def] \\ rveq)
      \\ qpat_x_assum `∀extra._` mp_tac
      \\ first_x_assum (qspec_then `k'` assume_tac)
      \\ first_assum (subterm (fn tm =>
            Cases_on`^(assert has_pair_type tm)`) o concl)
      \\ fs []
      \\ unabbrev_all_tac
      \\ strip_tac
      \\ drule (GEN_ALL let_evaluate_compile_prog)
      \\ impl_tac
      >- (last_x_assum (qspec_then `k+k'` mp_tac) \\ fs [])
      \\ strip_tac \\ rveq \\ fs []
      \\ reverse (Cases_on `s'.ffi.final_event`) \\ fs [] \\ rfs []
      >-
        (first_x_assum (qspec_then `ck + k` mp_tac)
        \\ fs [ADD1]
        \\ strip_tac \\ fs [state_rel_def] \\ rfs [])
      \\ qhdtm_x_assum `evaluate` mp_tac
      \\ imp_res_tac evaluate_add_clock
      \\ pop_assum kall_tac
      \\ pop_assum mp_tac
      \\ impl_tac
      >- (strip_tac \\ fs [])
      \\ disch_then (qspec_then `ck + k` mp_tac)
      \\ simp [inc_clock_def]
      \\ rpt strip_tac \\ rveq
      \\ CCONTR_TAC \\ fs []
      \\ rveq \\ fs [] \\ rfs [])
    \\ qmatch_assum_abbrev_tac `bvlSem$evaluate (exps2,[],st2) = _`
    \\ qspecl_then [`exps2`,`[]`,`st2`] mp_tac evaluate_add_to_clock_io_events_mono
    \\ simp [inc_clock_def, Abbr`st2`]
    \\ disch_then (qspec_then `0` strip_assume_tac)
    \\ first_assum (subterm (fn tm => Cases_on`^(assert(has_pair_type)tm)`) o concl)
    \\ unabbrev_all_tac
    \\ drule (GEN_ALL let_evaluate_compile_prog)
    \\ impl_tac
    >- (last_x_assum (qspec_then `k` mp_tac) \\ fs [])
    \\ strip_tac
    \\ asm_exists_tac \\ fs []
    \\ every_case_tac \\ fs [] \\ rveq \\ fs [])
  \\ strip_tac
  \\ simp [semantics_def]
  \\ IF_CASES_TAC \\ fs []
  >-
    (last_x_assum (qspec_then `k` assume_tac) \\ rfs []
    \\ first_assum (qspec_then `e` assume_tac)
    \\ fs [] \\ rfs []
    \\ qmatch_assum_abbrev_tac `FST q ≠ _`
    \\ Cases_on `q` \\ fs [markerTheory.Abbrev_def]
    \\ pop_assum (assume_tac o SYM)
    \\ drule (GEN_ALL let_evaluate_compile_prog)
    \\ simp []
    \\ spose_not_then strip_assume_tac
    \\ qmatch_assum_abbrev_tac `FST q = _`
    \\ Cases_on `q` \\ fs [markerTheory.Abbrev_def]
    \\ pop_assum (assume_tac o SYM)
    \\ imp_res_tac evaluate_add_clock \\ rfs []
    \\ first_x_assum (qspec_then `ck` mp_tac)
    \\ simp [inc_clock_def])
  \\ DEEP_INTRO_TAC some_intro \\ simp []
  \\ conj_tac
  >-
    (spose_not_then assume_tac \\ rw []
    \\ fsrw_tac [QUANT_INST_ss[pair_default_qp]] []
    \\ last_assum (qspec_then `k` mp_tac)
    \\ (fn g => subterm (fn tm => Cases_on`^(assert (can dest_prod o type_of) tm)` g) (#2 g))
    \\ strip_tac
    \\ drule (GEN_ALL let_evaluate_compile_prog)
    \\ impl_tac >- (last_x_assum (qspec_then `k` mp_tac) \\ fs [])
    \\ strip_tac
    \\ qmatch_assum_rename_tac `evaluate (_,[],_ k) = (_,rr)`
    \\ reverse (Cases_on `rr.ffi.final_event`)
    >-
      (first_x_assum
        (qspecl_then
          [`k`, `FFI_outcome(THE rr.ffi.final_event)`] mp_tac)
      \\ simp [])
    \\ qpat_x_assum `∀x y. ¬z` mp_tac \\ simp []
    \\ qexists_tac `k` \\ simp []
    \\ reverse (Cases_on `s.ffi.final_event`) \\ fs []
    >-
      (qhdtm_x_assum `evaluate` mp_tac
      \\ qmatch_assum_abbrev_tac `bvlSem$evaluate (opts1,[],os1) = (r,_)`
      \\ qspecl_then [`opts1`,`[]`,`os1`] mp_tac evaluate_add_to_clock_io_events_mono
      \\ disch_then (qspec_then `ck` mp_tac)
      \\ fs [ADD1, inc_clock_def, Abbr`os1`]
      \\ rpt strip_tac \\ fs []
      \\ fs [state_rel_def] \\ rfs [])
    \\ qhdtm_x_assum `evaluate` mp_tac
    \\ imp_res_tac evaluate_add_clock
    \\ pop_assum mp_tac
    \\ impl_tac
    >- (strip_tac \\ fs [])
    \\ disch_then (qspec_then `ck` mp_tac)
    \\ simp [inc_clock_def]
    \\ fs [ADD1]
    \\ rpt strip_tac \\ rveq \\ fs [])
  \\ strip_tac
  \\ qmatch_abbrev_tac `build_lprefix_lub l1 = build_lprefix_lub l2`
  \\ `(lprefix_chain l1 ∧ lprefix_chain l2) ∧ equiv_lprefix_chain l1 l2`
     suffices_by metis_tac [build_lprefix_lub_thm,
                            lprefix_lub_new_chain,
                            unique_lprefix_lub]
  \\ conj_asm1_tac
  >-
    (unabbrev_all_tac
    \\ conj_tac
    \\ Ho_Rewrite.ONCE_REWRITE_TAC [GSYM o_DEF]
    \\ REWRITE_TAC [IMAGE_COMPOSE]
    \\ match_mp_tac prefix_chain_lprefix_chain
    \\ simp [prefix_chain_def, PULL_EXISTS]
    \\ qx_genl_tac [`k1`,`k2`]
    \\ qspecl_then [`k1`,`k2`] mp_tac LESS_EQ_CASES
    \\ metis_tac [
         LESS_EQ_EXISTS,
         bviPropsTheory.initial_state_with_simp,
         bvlPropsTheory.initial_state_with_simp,
         bviPropsTheory.evaluate_add_to_clock_io_events_mono
           |> CONV_RULE(RESORT_FORALL_CONV(sort_vars["s"]))
           |> Q.SPEC`s with clock := k`
           |> SIMP_RULE (srw_ss())[bviPropsTheory.inc_clock_def],
         bvlPropsTheory.evaluate_add_to_clock_io_events_mono
           |> CONV_RULE(RESORT_FORALL_CONV(sort_vars["s"]))
           |> Q.SPEC`s with clock := k`
           |> SIMP_RULE (srw_ss())[bvlPropsTheory.inc_clock_def]])
  \\ simp [equiv_lprefix_chain_thm]
  \\ unabbrev_all_tac \\ simp [PULL_EXISTS]
  \\ simp [LNTH_fromList, PULL_EXISTS, GSYM FORALL_AND_THM]
  \\ rpt gen_tac
  \\ Cases_on `evaluate
         ([Call 0 (SOME start) []],[],
          initial_state ffi prog co (let_op_cc cc) k)`
  \\ drule (GEN_ALL let_evaluate_compile_prog_no_clock)
  \\ impl_tac >- (last_x_assum (qspec_then `k` mp_tac) \\ fs [])
  \\ strip_tac \\ fs []
  \\ conj_tac \\ rw []
  \\ qexists_tac `k` \\ fs []
  \\ qmatch_assum_abbrev_tac `_ < (LENGTH (_ ffi1))`
  \\ `ffi1.io_events ≼ r.ffi.io_events` by
    (qunabbrev_tac `ffi1`
    \\ metis_tac [
       initial_state_with_simp, evaluate_add_to_clock_io_events_mono
         |> CONV_RULE(RESORT_FORALL_CONV(sort_vars["s"]))
         |> Q.SPEC`s with clock := k`
         |> SIMP_RULE(srw_ss())[inc_clock_def],
       SND,ADD_SYM])
  \\ fs [IS_PREFIX_APPEND]
  \\ simp [EL_APPEND1]);


(* combined theorems *)

val remove_ticks_mk_tick = prove(
  ``!n r. remove_ticks [mk_tick n r] = remove_ticks [r]``,
  Induct THEN1 (EVAL_TAC \\ fs [])
  \\ fs [bvlTheory.mk_tick_def,FUNPOW,remove_ticks_def]);

val remove_ticks_tick_inline = prove(
  ``!cs xs.
      inline (map (I ## (λx. HD (remove_ticks [x]))) cs) xs =
      remove_ticks (tick_inline cs xs)``,
  ho_match_mp_tac inline_ind \\ rw []
  \\ fs [tick_inline_def,remove_ticks_def,inline_def]
  THEN1 (once_rewrite_tac [EQ_SYM_EQ] \\ simp [Once remove_ticks_CONS])
  \\ TOP_CASE_TAC \\ fs [tick_inline_def,remove_ticks_def,inline_def]
  \\ Cases_on `lookup x cs` \\ fs [lookup_map]
  \\ fs [tick_inline_def,remove_ticks_def,inline_def]
  \\ Cases_on `x'` \\ fs []
  \\ fs [remove_ticks_def,remove_ticks_mk_tick]);

val is_small_aux_0 = prove(
  ``!n:num xs. is_small_aux 0 xs = 0``,
  recInduct is_small_aux_ind
  \\ rw [] \\ fs [is_small_aux_def]);

val is_small_aux_CONS = prove(
  ``is_small_aux n (x::xs) =
    if n = 0 then n else
      let n = is_small_aux n [x] in
        if n = 0 then n else is_small_aux n xs``,
  Induct_on `xs` \\ fs [is_small_aux_def] \\ rw []
  \\ Cases_on `x` \\ fs [is_small_aux_def,is_small_aux_0]);

val is_small_aux_remove_ticks = prove(
  ``!limit d. is_small_aux limit (remove_ticks d) = is_small_aux limit d``,
  recInduct is_small_aux_ind \\ rw []
  \\ fs [is_small_aux_def,remove_ticks_def]
  \\ rw [] \\ fs []
  \\ once_rewrite_tac [is_small_aux_CONS] \\ fs []
  \\ simp [Once is_small_aux_CONS] \\ fs []);

val is_rec_CONS = prove(
  ``is_rec n (x::xs) <=> is_rec n [x] \/ is_rec n xs``,
  Cases_on `xs` \\ fs [is_rec_def]);

val is_rec_remove_ticks = prove(
  ``!p_1 xs. is_rec p_1 (remove_ticks xs) = is_rec p_1 xs``,
  recInduct is_rec_ind \\ rw []
  \\ fs [remove_ticks_def,is_rec_def]
  \\ simp [Once is_rec_CONS]
  \\ fs [] \\ fs [is_rec_def]
  \\ metis_tac []);

val must_inline_remove_ticks = prove(
  ``must_inline p_1 limit (HD (remove_ticks (tick_inline cs [p_2]))) =
    must_inline p_1 limit (HD ((tick_inline cs [p_2])))``,
  fs [must_inline_def]
  \\ `?d. tick_inline cs [p_2] = [d]` by
   (`LENGTH (tick_inline cs [p_2]) = LENGTH [p_2]`
       by metis_tac [LENGTH_tick_inline] \\ fs []
    \\ Cases_on `tick_inline cs [p_2]` \\ fs [])
  \\ fs [is_small_def,is_rec_def,is_small_aux_remove_ticks]
  \\ fs [is_rec_remove_ticks]);

val tick_inline_all_rel = prove(
  ``!prog cs xs.
      MAP (I ## I ## (λx. let_op_sing (HD (remove_ticks [x]))))
        (tick_inline_all limit cs prog xs) =
      inline_all limit (map (I ## (λx. HD (remove_ticks [x]))) cs)
        prog (MAP (I ## I ## (λx. let_op_sing (HD (remove_ticks [x])))) xs)``,
  Induct
  \\ fs [tick_inline_all_def,inline_all_def,MAP_REVERSE,FORALL_PROD]
  \\ fs [remove_ticks_tick_inline,must_inline_remove_ticks]
  \\ rw [] \\ fs [map_insert])
  |> Q.SPECL [`prog`,`LN`,`[]`]
  |> SIMP_RULE std_ss [MAP,map_def] |> GSYM
  |> REWRITE_RULE [GSYM compile_prog_def];

val map_fromAList_HASH = prove(
  ``map (I ## f) (fromAList ls) = fromAList (MAP (I ## I ## f) ls)``,
  fs [map_fromAList]
  \\ rpt (AP_TERM_TAC ORELSE AP_THM_TAC)
  \\ fs [FUN_EQ_THM,FORALL_PROD]);

val compile_prog_semantics = store_thm("compile_prog_semantics",
  ``ALL_DISTINCT (MAP FST prog) /\
    semantics ffi (fromAList prog) start <> Fail ==>
    semantics ffi (fromAList (compile_prog limit prog)) start =
    semantics ffi (fromAList prog) start``,
  fs [tick_inline_all_rel] \\ rw []
  \\ imp_res_tac (tick_compile_prog_semantics |> UNDISCH_ALL
      |> SIMP_RULE std_ss [Once (GSYM compile_prog_semantics)]
      |> DISCH_ALL)
  \\ qmatch_goalsub_abbrev_tac `MAP ff`
  \\ `ff = (I ## I ## let_op_sing) o (I ## I ## \x. (HD (remove_ticks [x])))`
       by fs [FUN_EQ_THM,Abbr `ff`,FORALL_PROD]
  \\ fs [GSYM MAP_MAP_o]
  \\ fs [GSYM map_fromAList_HASH,tick_compile_prog_def]
  \\ ntac 2 (pop_assum kall_tac)
  \\ once_rewrite_tac [EQ_SYM_EQ]
  \\ qpat_assum `_` (fn th => CONV_TAC (RATOR_CONV (ONCE_REWRITE_CONV [GSYM th])))
  \\ match_mp_tac (GSYM semantics_let_op) \\ fs []);

val map_fromAList = store_thm("map_fromAList",
  ``!xs f. map f (fromAList xs) = fromAList (MAP (I ## f) xs)``,
  Induct \\ fs [fromAList_def,fromAList_def,FORALL_PROD,map_insert]);

val inline_all_acc = Q.store_thm("inline_all_acc",
  `!xs ys cs limit.
      inline_all limit cs xs ys = REVERSE ys ++ inline_all limit cs xs []`,
  Induct \\ fs [inline_all_def] \\ strip_tac \\ PairCases_on `h` \\ fs []
  \\ once_rewrite_tac [inline_all_def] \\ simp_tac std_ss [LET_THM]
  \\ rpt strip_tac \\ IF_CASES_TAC
  \\ qpat_x_assum `!x._` (fn th => once_rewrite_tac [th]) \\ fs []);

val MAP_FST_inline_all = Q.store_thm("MAP_FST_inline_all",
  `!xs cs. MAP FST (inline_all limit cs xs []) = MAP FST xs`,
  Induct \\ fs [inline_all_def] \\ strip_tac
  \\ PairCases_on `h` \\ fs [inline_all_def] \\ rw []
  \\ once_rewrite_tac [inline_all_acc] \\ fs []);

val MAP_FST_compile_prog = Q.store_thm("MAP_FST_compile_prog",
  `MAP FST (compile_prog limit prog) = MAP FST prog`,
  fs [bvl_inlineTheory.compile_prog_def] \\ rw [MAP_FST_inline_all]);

val _ = export_theory();
