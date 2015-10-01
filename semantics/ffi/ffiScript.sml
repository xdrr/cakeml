(*Generated by Lem from ffi.lem.*)
open HolKernel Parse boolLib bossLib;
open lem_pervasivesTheory lem_pervasives_extraTheory libTheory;

val _ = numLib.prefer_num();



val _ = new_theory "ffi"

(*open import Pervasives*)
(*open import Pervasives_extra*)
(*open import Lib*)

(* An oracle says how to perform an ffi call based on its internal state,
 * represented by the type variable 'ffi. *)

val _ = type_abbrev((*  'ffi *) "oracle_function" , ``: 'ffi -> word8 list ->  ('ffi # ( word8 list))option``);
val _ = type_abbrev((*  'ffi *) "oracle" , ``: num -> 'ffi oracle_function``);

(* An I/O event, IO_event n bytes2, represents the call of FFI function n with
 * input map fst bytes2 in the passed array, returning map snd bytes2 in the
 * array. *)

val _ = Hol_datatype `
 io_event = IO_event of num => ( (word8 # word8)list)`;


val _ = Hol_datatype `
(*  'ffi *) ffi_state =
  <| oracle     : 'ffi oracle
   ; ffi_state  : 'ffi
   ; ffi_failed : bool
   ; io_events  : io_event list
   |>`;


(*val initial_ffi_state : forall 'ffi. oracle 'ffi -> 'ffi -> ffi_state 'ffi*)
val _ = Define `
 (initial_ffi_state oc ffi =  
(<| oracle     := oc
   ; ffi_state  := ffi
   ; ffi_failed := F
   ; io_events  := []
   |>))`;


(*val call_FFI : forall 'ffi. ffi_state 'ffi -> nat -> list word8 -> ffi_state 'ffi * list word8*)
val _ = Define `
 (call_FFI st n bytes =  
(if st.ffi_failed then (st, bytes) else
    (case st.oracle n st.ffi_state bytes of
      SOME (ffi', bytes') =>
        if LENGTH bytes' = LENGTH bytes then
          (( st with<| ffi_state := ffi'
                    ; io_events := (IO_event n (ZIP (bytes, bytes')))
                                  ::st.io_events
            |>), bytes')
        else (( st with<| ffi_failed := T |>), bytes)
    | _ => (( st with<| ffi_failed := T |>), bytes)
    )))`;


(* A program can Diverge, Terminate, or Fail. We prove that Fail is
   avoided. For Diverge and Terminate, we keep track of what I/O
   events are valid I/O events for this behaviour. *)
val _ = Hol_datatype `
  behaviour =
    (* There cannot be any non-returning FFI calls in a diverging
       exeuction. The list of I/O events can be finite or infinite,
       hence the llist (lazy list) type. *)
    Diverge of  io_event llist
    (* Terminating executions can only perform a finite number of
       FFI calls. The execution can be terminated by a non-returning
       FFI call. *)
  | Terminate of io_event list
    (* Failure is a behaviour which we prove cannot occur for any
       well-typed program. *)
  | Fail`;


(* trace-based semantics can be recovered as an instance of oracle-based
 * semantics as follows. *)

(*val trace_oracle : oracle (llist io_event)*)
val _ = Define `
 (trace_oracle n io_trace input =  
((case LHD io_trace of
    SOME (IO_event n' bytes2) =>
      if (n = n') /\ (MAP FST bytes2 = input) then
        SOME (THE (LTL io_trace), MAP SND bytes2)
      else NONE
  | _ => NONE
  )))`;

val _ = export_theory()

