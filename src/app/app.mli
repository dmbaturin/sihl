module Sig = App_sig

module Make : functor (Kernel : App_sig.KERNEL) (App : App_sig.APP) -> sig
  val start : unit -> unit
end
