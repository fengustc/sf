(** * Imp: Simple Imperative Programs *)

(** In this chapter, we begin a new direction that will continue for
    the rest of the course.  Up to now most of our attention has been
    focused on various aspects of Coq itself, while from now on we'll
    mostly be using Coq to formalize other things.  (We'll continue to
    pause from time to time to introduce a few additional aspects of
    Coq.)

    Our first case study is a _simple imperative programming language_
    called Imp, embodying a tiny core fragment of conventional
    mainstream languages such as C and Java.  Here is a familiar
    mathematical function written in Imp.
     Z ::= X;;
     Y ::= 1;;
     WHILE not (Z = 0) DO
       Y ::= Y * Z;;
       Z ::= Z - 1
     END
*)

(** This chapter looks at how to define the _syntax_ and _semantics_
    of Imp; the chapters that follow develop a theory of _program
    equivalence_ and introduce _Hoare Logic_, a widely used logic for
    reasoning about imperative programs. *)

(* ####################################################### *)
(** *** Sflib *)

(** A minor technical point: Instead of asking Coq to import our
    earlier definitions from chapter [Logic], we import a small library
    called [Sflib.v], containing just a few definitions and theorems
    from earlier chapters that we'll actually use in the rest of the
    course.  This change should be nearly invisible, since most of what's
    missing from Sflib has identical definitions in the Coq standard
    library.  The main reason for doing it is to tidy the global Coq
    environment so that, for example, it is easier to search for
    relevant theorems. *)

Require Export SfLib.

(* ####################################################### *)
(** * Arithmetic and Boolean Expressions *)

(** We'll present Imp in three parts: first a core language of
    _arithmetic and boolean expressions_, then an extension of these
    expressions with _variables_, and finally a language of _commands_
    including assignment, conditions, sequencing, and loops. *)

(* ####################################################### *)
(** ** Syntax *)

Module AExp.

(** These two definitions specify the _abstract syntax_ of
    arithmetic and boolean expressions. *)

Inductive aexp : Type :=
  | ANum : nat -> aexp
  | APlus : aexp -> aexp -> aexp
  | AMinus : aexp -> aexp -> aexp
  | AMult : aexp -> aexp -> aexp.

Inductive bexp : Type :=
  | BTrue : bexp
  | BFalse : bexp
  | BEq : aexp -> aexp -> bexp
  | BLe : aexp -> aexp -> bexp
  | BNot : bexp -> bexp
  | BAnd : bexp -> bexp -> bexp.

(** In this chapter, we'll elide the translation from the
    concrete syntax that a programmer would actually write to these
    abstract syntax trees -- the process that, for example, would
    translate the string ["1+2*3"] to the AST [APlus (ANum
    1) (AMult (ANum 2) (ANum 3))].  The optional chapter [ImpParser]
    develops a simple implementation of a lexical analyzer and parser
    that can perform this translation.  You do _not_ need to
    understand that file to understand this one, but if you haven't
    taken a course where these techniques are covered (e.g., a
    compilers course) you may want to skim it. *)

(** For comparison, here's a conventional BNF (Backus-Naur Form)
    grammar defining the same abstract syntax:
    a ::= nat
        | a + a
        | a - a
        | a * a

    b ::= true
        | false
        | a = a
        | a <= a
        | b and b
        | not b
*)

(** Compared to the Coq version above...

       - The BNF is more informal -- for example, it gives some
         suggestions about the surface syntax of expressions (like the
         fact that the addition operation is written [+] and is an
         infix symbol) while leaving other aspects of lexical analysis
         and parsing (like the relative precedence of [+], [-], and
         [*]) unspecified.  Some additional information -- and human
         intelligence -- would be required to turn this description
         into a formal definition (when implementing a compiler, for
         example).

         The Coq version consistently omits all this information and
         concentrates on the abstract syntax only.

       - On the other hand, the BNF version is lighter and
         easier to read.  Its informality makes it flexible, which is
         a huge advantage in situations like discussions at the
         blackboard, where conveying general ideas is more important
         than getting every detail nailed down precisely.

         Indeed, there are dozens of BNF-like notations and people
         switch freely among them, usually without bothering to say which
         form of BNF they're using because there is no need to: a
         rough-and-ready informal understanding is all that's
         needed. *)

(** It's good to be comfortable with both sorts of notations:
    informal ones for communicating between humans and formal ones for
    carrying out implementations and proofs. *)

(* ####################################################### *)
(** ** Evaluation *)

(** _Evaluating_ an arithmetic expression produces a number. *)

Fixpoint aeval (a : aexp) : nat :=
  match a with
  | ANum n => n
  | APlus a1 a2 => (aeval a1) + (aeval a2)
  | AMinus a1 a2  => (aeval a1) - (aeval a2)
  | AMult a1 a2 => (aeval a1) * (aeval a2)
  end.

Example test_aeval1:
  aeval (APlus (ANum 2) (ANum 2)) = 4.
Proof. reflexivity. Qed.

(** Similarly, evaluating a boolean expression yields a boolean. *)

Fixpoint beval (b : bexp) : bool :=
  match b with
  | BTrue       => true
  | BFalse      => false
  | BEq a1 a2   => beq_nat (aeval a1) (aeval a2)
  | BLe a1 a2   => ble_nat (aeval a1) (aeval a2)
  | BNot b1     => negb (beval b1)
  | BAnd b1 b2  => andb (beval b1) (beval b2)
  end.

(* ####################################################### *)
(** ** Optimization *)

(** We haven't defined very much yet, but we can already get
    some mileage out of the definitions.  Suppose we define a function
    that takes an arithmetic expression and slightly simplifies it,
    changing every occurrence of [0+e] (i.e., [(APlus (ANum 0) e])
    into just [e]. *)

Fixpoint optimize_0plus (a:aexp) : aexp :=
  match a with
  | ANum n =>
      ANum n
  | APlus (ANum 0) e2 =>
      optimize_0plus e2
  | APlus e1 e2 =>
      APlus (optimize_0plus e1) (optimize_0plus e2)
  | AMinus e1 e2 =>
      AMinus (optimize_0plus e1) (optimize_0plus e2)
  | AMult e1 e2 =>
      AMult (optimize_0plus e1) (optimize_0plus e2)
  end.

(** To make sure our optimization is doing the right thing we
    can test it on some examples and see if the output looks OK. *)

Example test_optimize_0plus:
  optimize_0plus (APlus (ANum 2)
                        (APlus (ANum 0)
                               (APlus (ANum 0) (ANum 1))))
  = APlus (ANum 2) (ANum 1).
Proof. reflexivity. Qed.

(** But if we want to be sure the optimization is correct --
    i.e., that evaluating an optimized expression gives the same
    result as the original -- we should prove it. *)

Theorem optimize_0plus_sound: forall a,
  aeval (optimize_0plus a) = aeval a.
Proof.
  intros a. induction a.
  Case "ANum". reflexivity.
  Case "APlus". destruct a1.
    SCase "a1 = ANum n". destruct n.
      SSCase "n = 0".  simpl. apply IHa2.
      SSCase "n <> 0". simpl. rewrite IHa2. reflexivity.
    SCase "a1 = APlus a1_1 a1_2".
      simpl. simpl in IHa1. rewrite IHa1.
      rewrite IHa2. reflexivity.
    SCase "a1 = AMinus a1_1 a1_2".
      simpl. simpl in IHa1. rewrite IHa1.
      rewrite IHa2. reflexivity.
    SCase "a1 = AMult a1_1 a1_2".
      simpl. simpl in IHa1. rewrite IHa1.
      rewrite IHa2. reflexivity.
  Case "AMinus".
    simpl. rewrite IHa1. rewrite IHa2. reflexivity.
  Case "AMult".
    simpl. rewrite IHa1. rewrite IHa2. reflexivity.  Qed.

(* ####################################################### *)
(** * Coq Automation *)

(** The repetition in this last proof is starting to be a little
    annoying.  If either the language of arithmetic expressions or the
    optimization being proved sound were significantly more complex,
    it would begin to be a real problem.

    So far, we've been doing all our proofs using just a small handful
    of Coq's tactics and completely ignoring its powerful facilities
    for constructing parts of proofs automatically.  This section
    introduces some of these facilities, and we will see more over the
    next several chapters.  Getting used to them will take some
    energy -- Coq's automation is a power tool -- but it will allow us
    to scale up our efforts to more complex definitions and more
    interesting properties without becoming overwhelmed by boring,
    repetitive, low-level details. *)

(* ####################################################### *)
(** ** Tacticals *)

(** _Tacticals_ is Coq's term for tactics that take other tactics as
    arguments -- "higher-order tactics," if you will.  *)

(* ####################################################### *)
(** *** The [repeat] Tactical *)

(** The [repeat] tactical takes another tactic and keeps applying
    this tactic until the tactic fails. Here is an example showing
    that [100] is even using repeat. *)

Theorem ev100 : ev 100.
Proof.
  repeat (apply ev_SS). (* applies ev_SS 50 times,
                           until [apply ev_SS] fails *)
  apply ev_0.
Qed.
 Print ev100.
(* Print ev100. *)

(** The [repeat T] tactic never fails; if the tactic [T] doesn't apply
    to the original goal, then repeat still succeeds without changing
    the original goal (it repeats zero times). *)

Theorem ev100' : ev 100.
Proof.
  repeat (apply ev_0). (* doesn't fail, applies ev_0 zero times *)
  repeat (apply ev_SS). apply ev_0. (* we can continue the proof *)
Qed.

(** The [repeat T] tactic does not have any bound on the number of
    times it applies [T]. If [T] is a tactic that always succeeds then
    repeat [T] will loop forever (e.g. [repeat simpl] loops forever
    since [simpl] always succeeds). While Coq's term language is
    guaranteed to terminate, Coq's tactic language is not! *)

(* ####################################################### *)
(** *** The [try] Tactical *)

(** If [T] is a tactic, then [try T] is a tactic that is just like [T]
    except that, if [T] fails, [try T] _successfully_ does nothing at
    all (instead of failing). *)

Theorem silly1 : forall ae, aeval ae = aeval ae.
Proof. try reflexivity. (* this just does [reflexivity] *) Qed.

Theorem silly2 : forall (P : Prop), P -> P.
Proof.
  intros P HP.
  try reflexivity. (* just [reflexivity] would have failed *)
  apply HP. (* we can still finish the proof in some other way *)
Qed.

(** Using [try] in a completely manual proof is a bit silly, but
    we'll see below that [try] is very useful for doing automated
    proofs in conjunction with the [;] tactical. *)

(* ####################################################### *)
(** *** The [;] Tactical (Simple Form) *)

(** In its most commonly used form, the [;] tactical takes two tactics
    as argument: [T;T'] first performs the tactic [T] and then
    performs the tactic [T'] on _each subgoal_ generated by [T]. *)

(** For example, consider the following trivial lemma: *)

Lemma foo : forall n, ble_nat 0 n = true.
Proof.
  intros.
  destruct n.
    (* Leaves two subgoals, which are discharged identically...  *)
    Case "n=0". simpl. reflexivity.
    Case "n=Sn'". simpl. reflexivity.
Qed.

(** We can simplify this proof using the [;] tactical: *)

Lemma foo' : forall n, ble_nat 0 n = true.
Proof.
  intros.
  destruct n; (* [destruct] the current goal *)
  simpl; (* then [simpl] each resulting subgoal *)
  reflexivity. (* and do [reflexivity] on each resulting subgoal *)
Qed.

(** Using [try] and [;] together, we can get rid of the repetition in
    the proof that was bothering us a little while ago. *)

Theorem optimize_0plus_sound': forall a,
  aeval (optimize_0plus a) = aeval a.
Proof.
  intros a.
  induction a;
    (* Most cases follow directly by the IH *)
    try (simpl; rewrite IHa1; rewrite IHa2; reflexivity).
  (* The remaining cases -- ANum and APlus -- are different *)
  Case "ANum". reflexivity.
  Case "APlus".
    destruct a1;
      (* Again, most cases follow directly by the IH *)
      try (simpl; simpl in IHa1; rewrite IHa1;
           rewrite IHa2; reflexivity).
    (* The interesting case, on which the [try...] does nothing,
       is when [e1 = ANum n]. In this case, we have to destruct
       [n] (to see whether the optimization applies) and rewrite
       with the induction hypothesis. *)
    SCase "a1 = ANum n". destruct n;
      simpl; rewrite IHa2; reflexivity.   Qed.

(** Coq experts often use this "[...; try... ]" idiom after a tactic
    like [induction] to take care of many similar cases all at once.
    Naturally, this practice has an analog in informal proofs.

    Here is an informal proof of this theorem that matches the
    structure of the formal one:

    _Theorem_: For all arithmetic expressions [a],
       aeval (optimize_0plus a) = aeval a.
    _Proof_: By induction on [a].  The [AMinus] and [AMult] cases
    follow directly from the IH.  The remaining cases are as follows:

      - Suppose [a = ANum n] for some [n].  We must show
          aeval (optimize_0plus (ANum n)) = aeval (ANum n).
        This is immediate from the definition of [optimize_0plus].

      - Suppose [a = APlus a1 a2] for some [a1] and [a2].  We
        must show
          aeval (optimize_0plus (APlus a1 a2))
        = aeval (APlus a1 a2).
        Consider the possible forms of [a1].  For most of them,
        [optimize_0plus] simply calls itself recursively for the
        subexpressions and rebuilds a new expression of the same form
        as [a1]; in these cases, the result follows directly from the
        IH.

        The interesting case is when [a1 = ANum n] for some [n].
        If [n = ANum 0], then
          optimize_0plus (APlus a1 a2) = optimize_0plus a2
        and the IH for [a2] is exactly what we need.  On the other
        hand, if [n = S n'] for some [n'], then again [optimize_0plus]
        simply calls itself recursively, and the result follows from
        the IH.  [] *)

(** This proof can still be improved: the first case (for [a = ANum
    n]) is very trivial -- even more trivial than the cases that we
    said simply followed from the IH -- yet we have chosen to write it
    out in full.  It would be better and clearer to drop it and just
    say, at the top, "Most cases are either immediate or direct from
    the IH.  The only interesting case is the one for [APlus]..."  We
    can make the same improvement in our formal proof too.  Here's how
    it looks: *)

Theorem optimize_0plus_sound'': forall a,
  aeval (optimize_0plus a) = aeval a.
Proof.
  intros a.
  induction a;
    (* Most cases follow directly by the IH *)
    try (simpl; rewrite IHa1; rewrite IHa2; reflexivity);
    (* ... or are immediate by definition *)
    try reflexivity.
  (* The interesting case is when a = APlus a1 a2. *)
  Case "APlus".
    destruct a1; try (simpl; simpl in IHa1; rewrite IHa1;
                      rewrite IHa2; reflexivity).
    SCase "a1 = ANum n". destruct n;
      simpl; rewrite IHa2; reflexivity. Qed.

(* ####################################################### *)
(** *** The [;] Tactical (General Form) *)

(** The [;] tactical has a more general than the simple [T;T'] we've
    seen above, which is sometimes also useful.  If [T], [T1], ...,
    [Tn] are tactics, then
      T; [T1 | T2 | ... | Tn]
   is a tactic that first performs [T] and then performs [T1] on the
   first subgoal generated by [T], performs [T2] on the second
   subgoal, etc.

   So [T;T'] is just special notation for the case when all of the
   [Ti]'s are the same tactic; i.e. [T;T'] is just a shorthand for:
      T; [T' | T' | ... | T']
*)

(* ####################################################### *)
(** ** Defining New Tactic Notations *)

(** Coq also provides several ways of "programming" tactic scripts.

      - The [Tactic Notation] idiom illustrated below gives a handy
        way to define "shorthand tactics" that bundle several tactics
        into a single command.

      - For more sophisticated programming, Coq offers a small
        built-in programming language called [Ltac] with primitives
        that can examine and modify the proof state.  The details are
        a bit too complicated to get into here (and it is generally
        agreed that [Ltac] is not the most beautiful part of Coq's
        design!), but they can be found in the reference manual, and
        there are many examples of [Ltac] definitions in the Coq
        standard library that you can use as examples.

      - There is also an OCaml API, which can be used to build tactics
        that access Coq's internal structures at a lower level, but
        this is seldom worth the trouble for ordinary Coq users.

The [Tactic Notation] mechanism is the easiest to come to grips with,
and it offers plenty of power for many purposes.  Here's an example.
*)

Tactic Notation "simpl_and_try" tactic(c) :=
  simpl;
  try c.

(** This defines a new tactical called [simpl_and_try] which
    takes one tactic [c] as an argument, and is defined to be
    equivalent to the tactic [simpl; try c].  For example, writing
    "[simpl_and_try reflexivity.]" in a proof would be the same as
    writing "[simpl; try reflexivity.]" *)

(** The next subsection gives a more sophisticated use of this
    feature... *)

(* ####################################################### *)
(** *** Bulletproofing Case Analyses *)

(** Being able to deal with most of the cases of an [induction]
    or [destruct] all at the same time is very convenient, but it can
    also be a little confusing.  One problem that often comes up is
    that _maintaining_ proofs written in this style can be difficult.
    For example, suppose that, later, we extended the definition of
    [aexp] with another constructor that also required a special
    argument.  The above proof might break because Coq generated the
    subgoals for this constructor before the one for [APlus], so that,
    at the point when we start working on the [APlus] case, Coq is
    actually expecting the argument for a completely different
    constructor.  What we'd like is to get a sensible error message
    saying "I was expecting the [AFoo] case at this point, but the
    proof script is talking about [APlus]."  Here's a nice trick (due
    to Aaron Bohannon) that smoothly achieves this. *)

Tactic Notation "aexp_cases" tactic(first) ident(c) :=
  first;
  [ Case_aux c "ANum" | Case_aux c "APlus"
  | Case_aux c "AMinus" | Case_aux c "AMult" ].

(** ([Case_aux] implements the common functionality of [Case],
    [SCase], [SSCase], etc.  For example, [Case "foo"] is defined as
    [Case_aux Case "foo".) *)

(** For example, if [a] is a variable of type [aexp], then doing
      aexp_cases (induction a) Case
    will perform an induction on [a] (the same as if we had just typed
    [induction a]) and _also_ add a [Case] tag to each subgoal
    generated by the [induction], labeling which constructor it comes
    from.  For example, here is yet another proof of
    [optimize_0plus_sound], using [aexp_cases]: *)

Theorem optimize_0plus_sound''': forall a,
  aeval (optimize_0plus a) = aeval a.
Proof.
  intros a.
  aexp_cases (induction a) Case;
    try (simpl; rewrite IHa1; rewrite IHa2; reflexivity);
    try reflexivity.
  (* At this point, there is already an ["A Plus"] case name
     in the context.  The [Case "APlus"] here in the proof 
     text has the effect of a sanity check: if the "Case"
     string in the context is anything _other_ than ["APlus"]
     (for example, because we added a clause to the definition
     of [aexp] and forgot to change the proof) we'll get a
     helpful error at this point telling us that this is now
     the wrong case. *)
  Case "APlus".
    aexp_cases (destruct a1) SCase;
      try (simpl; simpl in IHa1;
           rewrite IHa1; rewrite IHa2; reflexivity).
    SCase "ANum". destruct n;
      simpl; rewrite IHa2; reflexivity.  Qed.

(** **** Exercise: 3 stars (optimize_0plus_b) *)
(** Since the [optimize_0plus] tranformation doesn't change the value
    of [aexp]s, we should be able to apply it to all the [aexp]s that
    appear in a [bexp] without changing the [bexp]'s value.  Write a
    function which performs that transformation on [bexp]s, and prove
    it is sound.  Use the tacticals we've just seen to make the proof
    as elegant as possible. *)

Fixpoint optimize_0plus_b (b : bexp) : bexp :=
  match b with

  |BAnd BFalse b2 => BFalse
  |BEq a1 a2=>
     BEq (optimize_0plus a1)(optimize_0plus a2)
  |BLe a1 a2=>
     BLe (optimize_0plus a1) (optimize_0plus a2)
  |BNot b1=>BNot (optimize_0plus_b b1)
  |BAnd b1 b2=>
     BAnd (optimize_0plus_b b1)(optimize_0plus_b b2) 
  |BFalse=>BFalse
  |BTure=>BTure
  end.
  (* FILL IN HERE *)
Theorem optimize_0plus_b_sound : forall b,
  beval (optimize_0plus_b b) = beval b.
Proof.
  intros b. induction b.
  Case "Btrue". reflexivity.
  Case "BFalse". reflexivity.
  Case "BEq a1 a2". simpl. rewrite->optimize_0plus_sound.
       rewrite->optimize_0plus_sound. reflexivity.
  Case "BLe a1 a2". simpl. rewrite->optimize_0plus_sound.
       rewrite->optimize_0plus_sound. reflexivity.
  Case "BNot b1". simpl. rewrite->IHb. reflexivity.
  Case "BAnd b1 b2". destruct b1.
    SCase "b1=BTrue". simpl. rewrite->IHb2. reflexivity.
    SCase "b1=BFalse". simpl. reflexivity.
    SCase "b1=BEq a1 a2". simpl. rewrite->optimize_0plus_sound.
                          rewrite->optimize_0plus_sound.
                          rewrite->IHb2. reflexivity.
    SCase "b1=BLe a1 a2". simpl. rewrite->optimize_0plus_sound.
                          rewrite->optimize_0plus_sound.
                          rewrite->IHb2. reflexivity.
    SCase "BNot b1". simpl. rewrite->IHb2. simpl in IHb1.
                     rewrite->IHb1. reflexivity.
    SCase "BAnd b1 b2". simpl. simpl in IHb1. rewrite->IHb1.
                      rewrite->IHb2. reflexivity.
Qed.


Theorem optimize_0plus_b_sound' : forall b,
  beval (optimize_0plus_b b) = beval b.
Proof.
  intros b. induction b;
  try(reflexivity);
  try(simpl; rewrite->optimize_0plus_sound;rewrite->optimize_0plus_sound;reflexivity).
  Case "BNot b1". simpl. rewrite->IHb. reflexivity.
  Case "BAnd b1 b2". destruct b1;
    try simpl;try rewrite->IHb2;try reflexivity;
    try (rewrite->optimize_0plus_sound;rewrite->optimize_0plus_sound;reflexivity);
    try( simpl;simpl in IHb1;rewrite->IHb1;reflexivity).
Qed.
  (* FILL IN HERE *)
(** [] *)

(** **** Exercise: 4 stars, optional (optimizer) *)
(** _Design exercise_: The optimization implemented by our
    [optimize_0plus] function is only one of many imaginable
    optimizations on arithmetic and boolean expressions.  Write a more
    sophisticated optimizer and prove it correct.
*)
Fixpoint optimizer (a:aexp) : aexp :=
  match a with
  | ANum n =>
      ANum n
  | APlus (ANum 0) e2 =>
      optimizer e2
  | APlus e1 e2 =>
      APlus (optimizer e1) (optimizer e2)
  | AMinus (ANum 0) e2 => ANum 0
  | AMinus e1 e2 =>
      AMinus (optimizer e1) (optimizer e2)
  | AMult e1 e2 =>
      AMult (optimizer e1) (optimizer e2)
  end.
Theorem optimizer_sound: forall a,
  aeval (optimizer a) = aeval a.
Proof.
  intro. induction a.
  Case "ANum n". reflexivity.
  Case "Aplus a1 a2". destruct a1.
    SCase "a1=ANum n". destruct n.
       SSCase "n=0". simpl. rewrite->IHa2. reflexivity.
       SSCase "n<>0". simpl. rewrite->IHa2. reflexivity.  
    SCase "a1=Aplus a1 a2". simpl. simpl in IHa1. rewrite->IHa1.
                           rewrite->IHa2. reflexivity. 
    SCase "a1=AMinus a1 a2". simpl. simpl in IHa1. rewrite->IHa1.
                           rewrite->IHa2. reflexivity. 
    SCase "AMult a1 a2".  simpl. simpl in IHa1. rewrite->IHa1.
                           rewrite->IHa2. reflexivity.
  Case "AMinus a1 a2". destruct a1. 
    SCase "a1=ANum n". destruct n.
       SSCase "n=0". simpl. reflexivity.
       SSCase "n<>0". simpl.  rewrite->IHa2. reflexivity.
    SCase "a1=Aplus a1 a2". simpl. simpl in IHa1. rewrite->IHa1. rewrite->IHa2. reflexivity. 
    SCase "a1=AMinus a1 a2". simpl. simpl in IHa1. rewrite->IHa1. rewrite->IHa2. reflexivity.
    SCase "AMult a1 a2". simpl. simpl in IHa1. rewrite->IHa1. rewrite->IHa2. reflexivity.
  Case "AMult a1 a2".
    simpl. rewrite->IHa1. rewrite->IHa2. reflexivity.
Qed.
(* FILL IN HERE *)

(** [] *)

(* ####################################################### *)
(** ** The [omega] Tactic *)

(** The [omega] tactic implements a decision procedure for a subset of
    first-order logic called _Presburger arithmetic_.  It is based on
    the Omega algorithm invented in 1992 by William Pugh.

    If the goal is a universally quantified formula made out of

      - numeric constants, addition ([+] and [S]), subtraction ([-]
        and [pred]), and multiplication by constants (this is what
        makes it Presburger arithmetic),

      - equality ([=] and [<>]) and inequality ([<=]), and

      - the logical connectives [/\], [\/], [~], and [->],

    then invoking [omega] will either solve the goal or tell you that
    it is actually false. *)

Example silly_presburger_example : forall m n o p,
  m + n <= n + o /\ o + 3 = p + 3 ->
  m <= p.
Proof.
  intros. omega.
Qed.

(** Liebniz wrote, "It is unworthy of excellent men to lose
    hours like slaves in the labor of calculation which could be
    relegated to anyone else if machines were used."  We recommend
    using the omega tactic whenever possible. *)

(* ####################################################### *)
(** ** A Few More Handy Tactics *)

(** Finally, here are some miscellaneous tactics that you may find
    convenient.

     - [clear H]: Delete hypothesis [H] from the context.

     - [subst x]: Find an assumption [x = e] or [e = x] in the
       context, replace [x] with [e] throughout the context and
       current goal, and clear the assumption.

     - [subst]: Substitute away _all_ assumptions of the form [x = e]
       or [e = x].

     - [rename... into...]: Change the name of a hypothesis in the
       proof context.  For example, if the context includes a variable
       named [x], then [rename x into y] will change all occurrences
       of [x] to [y].

     - [assumption]: Try to find a hypothesis [H] in the context that
       exactly matches the goal; if one is found, behave just like
       [apply H].

     - [contradiction]: Try to find a hypothesis [H] in the current
       context that is logically equivalent to [False].  If one is
       found, solve the goal.

     - [constructor]: Try to find a constructor [c] (from some
       [Inductive] definition in the current environment) that can be
       applied to solve the current goal.  If one is found, behave
       like [apply c]. *)

(** We'll see many examples of these in the proofs below. *)

(* ####################################################### *)
(** * Evaluation as a Relation *)

(** We have presented [aeval] and [beval] as functions defined by
    [Fixpoints].  Another way to think about evaluation -- one that we
    will see is often more flexible -- is as a _relation_ between
    expressions and their values.  This leads naturally to [Inductive]
    definitions like the following one for arithmetic
    expressions... *)

Module aevalR_first_try.

Inductive aevalR : aexp -> nat -> Prop :=
  | E_ANum  : forall (n: nat),
      aevalR (ANum n) n
  | E_APlus : forall (e1 e2: aexp) (n1 n2: nat),
      aevalR e1 n1 ->
      aevalR e2 n2 ->
      aevalR (APlus e1 e2) (n1 + n2)
  | E_AMinus: forall (e1 e2: aexp) (n1 n2: nat),
      aevalR e1 n1 ->
      aevalR e2 n2 ->
      aevalR (AMinus e1 e2) (n1 - n2)
  | E_AMult : forall (e1 e2: aexp) (n1 n2: nat),
      aevalR e1 n1 ->
      aevalR e2 n2 ->
      aevalR (AMult e1 e2) (n1 * n2).

(** As is often the case with relations, we'll find it
    convenient to define infix notation for [aevalR].  We'll write [e
    || n] to mean that arithmetic expression [e] evaluates to value
    [n].  (This notation is one place where the limitation to ASCII
    symbols becomes a little bothersome.  The standard notation for
    the evaluation relation is a double down-arrow.  We'll typeset it
    like this in the HTML version of the notes and use a double
    vertical bar as the closest approximation in [.v] files.)  *)

Notation "e '||' n" := (aevalR e n) : type_scope.

End aevalR_first_try.

(** In fact, Coq provides a way to use this notation in the definition
    of [aevalR] itself.  This avoids situations where we're working on
    a proof involving statements in the form [e || n] but we have to
    refer back to a definition written using the form [aevalR e n].

    We do this by first "reserving" the notation, then giving the
    definition together with a declaration of what the notation
    means. *)

Reserved Notation "e '||' n" (at level 50, left associativity).

Inductive aevalR : aexp -> nat -> Prop :=
  | E_ANum : forall (n:nat),
      (ANum n) || n
  | E_APlus : forall (e1 e2: aexp) (n1 n2 : nat),
      (e1 || n1) -> (e2 || n2) -> (APlus e1 e2) || (n1 + n2)
  | E_AMinus : forall (e1 e2: aexp) (n1 n2 : nat),
      (e1 || n1) -> (e2 || n2) -> (AMinus e1 e2) || (n1 - n2)
  | E_AMult :  forall (e1 e2: aexp) (n1 n2 : nat),
      (e1 || n1) -> (e2 || n2) -> (AMult e1 e2) || (n1 * n2)

  where "e '||' n" := (aevalR e n) : type_scope.

Tactic Notation "aevalR_cases" tactic(first) ident(c) :=
  first;
  [ Case_aux c "E_ANum" | Case_aux c "E_APlus"
  | Case_aux c "E_AMinus" | Case_aux c "E_AMult" ].

(* ####################################################### *)
(** ** Inference Rule Notation *)

(** In informal discussions, it is convenient write the rules for
    [aevalR] and similar relations in the more readable graphical form
    of _inference rules_, where the premises above the line justify
    the conclusion below the line (we have already seen them in the
    Prop chapter). *)

(** For example, the constructor [E_APlus]...
      | E_APlus : forall (e1 e2: aexp) (n1 n2: nat),
          aevalR e1 n1 ->
          aevalR e2 n2 ->
          aevalR (APlus e1 e2) (n1 + n2)
    ...would be written like this as an inference rule:
                               e1 || n1
                               e2 || n2
                         --------------------                         (E_APlus)
                         APlus e1 e2 || n1+n2
*)

(** Formally, there is nothing very deep about inference rules:
    they are just implications.  You can read the rule name on the
    right as the name of the constructor and read each of the
    linebreaks between the premises above the line and the line itself
    as [->].  All the variables mentioned in the rule ([e1], [n1],
    etc.) are implicitly bound by universal quantifiers at the
    beginning. (Such variables are often called _metavariables_ to
    distinguish them from the variables of the language we are
    defining.  At the moment, our arithmetic expressions don't include
    variables, but we'll soon be adding them.)  The whole collection
    of rules is understood as being wrapped in an [Inductive]
    declaration (informally, this is either elided or else indicated
    by saying something like "Let [aevalR] be the smallest relation
    closed under the following rules..."). *)

(** For example, [||] is the smallest relation closed under these
    rules:
                             -----------                               (E_ANum)
                             ANum n || n

                               e1 || n1
                               e2 || n2
                         --------------------                         (E_APlus)
                         APlus e1 e2 || n1+n2

                               e1 || n1
                               e2 || n2
                        ---------------------                        (E_AMinus)
                        AMinus e1 e2 || n1-n2

                               e1 || n1
                               e2 || n2
                         --------------------                         (E_AMult)
                         AMult e1 e2 || n1*n2
*)

(* ####################################################### *)
(** ** Equivalence of the Definitions *)

(** It is straightforward to prove that the relational and functional
    definitions of evaluation agree on all possible arithmetic
    expressions... *)

Theorem aeval_iff_aevalR : forall a n,
  (a || n) <-> aeval a = n.
Proof.
 split.
 Case "->".
   intros H.
   aevalR_cases (induction H) SCase; simpl.
   SCase "E_ANum".
     reflexivity.
   SCase "E_APlus".
     rewrite IHaevalR1.  rewrite IHaevalR2.  reflexivity.
   SCase "E_AMinus".
     rewrite IHaevalR1.  rewrite IHaevalR2.  reflexivity.
   SCase "E_AMult".
     rewrite IHaevalR1.  rewrite IHaevalR2.  reflexivity.
 Case "<-".
   generalize dependent n.
   aexp_cases (induction a) SCase;
      simpl; intros; subst.
   SCase "ANum".
     apply E_ANum.
   SCase "APlus".
     apply E_APlus.
      apply IHa1. reflexivity.
      apply IHa2. reflexivity.
   SCase "AMinus".
     apply E_AMinus.
      apply IHa1. reflexivity.
      apply IHa2. reflexivity.
   SCase "AMult".
     apply E_AMult.
      apply IHa1. reflexivity.
      apply IHa2. reflexivity.
Qed.

(** Note: if you're reading the HTML file, you'll see an empty square box instead
of a proof for this theorem.  
You can click on this box to "unfold" the text to see the proof.
Click on the unfolded to text to "fold" it back up to a box. We'll be using
this style frequently from now on to help keep the HTML easier to read.
The full proofs always appear in the .v files. *)

(** We can make the proof quite a bit shorter by making more
    use of tacticals... *)

Theorem aeval_iff_aevalR' : forall a n,
  (a || n) <-> aeval a = n.
Proof.
  (* WORKED IN CLASS *)
  split.
  Case "->".
    intros H; induction H; subst; reflexivity.
  Case "<-".
    generalize dependent n.
    induction a; simpl; intros; subst; constructor;
       try apply IHa1; try apply IHa2; reflexivity.
Qed.

(** **** Exercise: 3 stars  (bevalR) *)
(** Write a relation [bevalR] in the same style as
    [aevalR], and prove that it is equivalent to [beval].*)
Inductive bevalR: bexp -> bool -> Prop :=
  |E_BTrue : 
      BTrue ||| true
  |E_BFalse :
      BFalse ||| false
  |E_BEq: forall(a1 a2 : aexp),
      (BEq a1 a2) ||| (beq_nat (aeval a1) (aeval a2))
  |E_BLe: forall(a1 a2 : aexp),
      (BLe a1 a2) ||| (ble_nat (aeval a1) (aeval a2))
  |E_BNot: forall(e : bexp) (b:bool),
      (e ||| b)->(BNot e)||| (negb b)
  |E_BAnd: forall (e1 e2 : bexp)(b1 b2 : bool),
      (e1 ||| b1)->(e2 ||| b2)->(BAnd e1 e2) ||| (andb b1 b2)
  where "e '|||' b" := (bevalR e b):type_scope.

Theorem beval_iff_bevalR : forall (e:bexp) (b:bool),
  (e ||| b) <-> beval e = b.
Proof.
  split.
  Case "->". 
    intro H.
    induction H; simpl.
    SCase "E_BTrue". reflexivity.
    SCase "E_BFalse". reflexivity.
    SCase "E_BEq". reflexivity. 
    SCase "E_BLe". reflexivity.
    SCase "E_BNot". rewrite->IHbevalR. reflexivity.
    SCase "E_BAnd". rewrite->IHbevalR1. rewrite->IHbevalR2. reflexivity.
  Case "<-".
    generalize dependent b.
    induction e.
    SCase "BTrue". simpl. intros. rewrite<-H. apply E_BTrue.
    SCase "BFalse". simpl. intros. rewrite<-H. apply E_BFalse.
    SCase "BEq". simpl. intros. rewrite<-H. apply E_BEq.
    SCase "BLe". simpl. intros. rewrite<-H. apply E_BLe.
    SCase "BNot". simpl. intros. rewrite<-H. apply E_BNot.
                  apply IHe. reflexivity.
    SCase "E_BAnd". simpl. intros. rewrite<-H. apply E_BAnd.
                  apply IHe1. reflexivity. apply IHe2. reflexivity. 
Qed.
(* 
Inductive bevalR:
(* FILL IN HERE *)
*)
(** [] *)
End AExp.

(* ####################################################### *)
(** ** Computational vs. Relational Definitions *)

(** For the definitions of evaluation for arithmetic and boolean
    expressions, the choice of whether to use functional or relational
    definitions is mainly a matter of taste.  In general, Coq has
    somewhat better support for working with relations.  On the other
    hand, in some sense function definitions carry more information,
    because functions are necessarily deterministic and defined on all
    arguments; for a relation we have to show these properties
    explicitly if we need them. Functions also take advantage of Coq's
    computations mechanism.

    However, there are circumstances where relational definitions of
    evaluation are preferable to functional ones.  *)

Module aevalR_division.

(** For example, suppose that we wanted to extend the arithmetic
    operations by considering also a division operation:*)

Inductive aexp : Type :=
  | ANum : nat -> aexp
  | APlus : aexp -> aexp -> aexp
  | AMinus : aexp -> aexp -> aexp
  | AMult : aexp -> aexp -> aexp
  | ADiv : aexp -> aexp -> aexp.   (* <--- new *)

(** Extending the definition of [aeval] to handle this new operation
    would not be straightforward (what should we return as the result
    of [ADiv (ANum 5) (ANum 0)]?).  But extending [aevalR] is
    straightforward. *)

Inductive aevalR : aexp -> nat -> Prop :=
  | E_ANum : forall (n:nat),
      (ANum n) || n
  | E_APlus : forall (a1 a2: aexp) (n1 n2 : nat),
      (a1 || n1) -> (a2 || n2) -> (APlus a1 a2) || (n1 + n2)
  | E_AMinus : forall (a1 a2: aexp) (n1 n2 : nat),
      (a1 || n1) -> (a2 || n2) -> (AMinus a1 a2) || (n1 - n2)
  | E_AMult :  forall (a1 a2: aexp) (n1 n2 : nat),
      (a1 || n1) -> (a2 || n2) -> (AMult a1 a2) || (n1 * n2)
  | E_ADiv :  forall (a1 a2: aexp) (n1 n2 n3: nat),
      (a1 || n1) -> (a2 || n2) -> (mult n2 n3 = n1) -> (ADiv a1 a2) || n3

where "a '||' n" := (aevalR a n) : type_scope.

End aevalR_division.
Module aevalR_extended.

Inductive aexp : Type :=
  | AAny  : aexp                   (* <--- NEW *)
  | ANum : nat -> aexp
  | APlus : aexp -> aexp -> aexp
  | AMinus : aexp -> aexp -> aexp
  | AMult : aexp -> aexp -> aexp.

(** Again, extending [aeval] would be tricky (because evaluation is
    _not_ a deterministic function from expressions to numbers), but
    extending [aevalR] is no problem: *)

Inductive aevalR : aexp -> nat -> Prop :=
  | E_Any : forall (n:nat),
      AAny || n                 (* <--- new *)
  | E_ANum : forall (n:nat),
      (ANum n) || n
  | E_APlus : forall (a1 a2: aexp) (n1 n2 : nat),
      (a1 || n1) -> (a2 || n2) -> (APlus a1 a2) || (n1 + n2)
  | E_AMinus : forall (a1 a2: aexp) (n1 n2 : nat),
      (a1 || n1) -> (a2 || n2) -> (AMinus a1 a2) || (n1 - n2)
  | E_AMult :  forall (a1 a2: aexp) (n1 n2 : nat),
      (a1 || n1) -> (a2 || n2) -> (AMult a1 a2) || (n1 * n2)

where "a '||' n" := (aevalR a n) : type_scope.

End aevalR_extended.

(** * Expressions With Variables *)

(** Let's turn our attention back to defining Imp.  The next thing we
    need to do is to enrich our arithmetic and boolean expressions
    with variables.  To keep things simple, we'll assume that all
    variables are global and that they only hold numbers. *)

(* ##################################################### *)
(** ** Identifiers *)

(** To begin, we'll need to formalize _identifiers_ such as program
    variables.  We could use strings for this -- or, in a real
    compiler, fancier structures like pointers into a symbol table.
    But for simplicity let's just use natural numbers as identifiers. *)

(** (We hide this section in a module because these definitions are
    actually in [SfLib], but we want to repeat them here so that we
    can explain them.) *)

Module Id. 

(** We define a new inductive datatype [Id] so that we won't confuse
    identifiers and numbers.  We use [sumbool] to define a computable
    equality operator on [Id]. *)

Inductive id : Type :=
  Id : nat -> id.

Theorem eq_id_dec : forall id1 id2 : id, {id1 = id2} + {id1 <> id2}.
Proof.
   intros id1 id2.
   destruct id1 as [n1]. destruct id2 as [n2].
   destruct (eq_nat_dec n1 n2) as [Heq | Hneq].
   Case "n1 = n2".
     left. rewrite Heq. reflexivity.
   Case "n1 <> n2".
     right. intros contra. inversion contra. apply Hneq. apply H0.
Defined. 

(** The following lemmas will be useful for rewriting terms involving [eq_id_dec]. *)

Lemma eq_id : forall (T:Type) x (p q:T), 
              (if eq_id_dec x x then p else q) = p. 
Proof.
  intros. 
  destruct (eq_id_dec x x). 
  Case "x = x". 
    reflexivity.
  Case "x <> x (impossible)". 
    apply ex_falso_quodlibet; apply n; reflexivity. Qed.

(** **** Exercise: 1 star, optional (neq_id) *)
Lemma neq_id : forall (T:Type) x y (p q:T), x <> y -> 
               (if eq_id_dec x y then p else q) = q. 
Proof.
  intros.
  destruct (eq_id_dec x y).
  Case "x=y". apply ex_falso_quodlibet. apply H. apply e.
  Case "x<>y". reflexivity.
Qed.
  (* FILL IN HERE *)
(** [] *)


End Id. 

(* ####################################################### *)
(** ** States *)

(** A _state_ represents the current values of all the variables at
    some point in the execution of a program. *)
(** For simplicity (to avoid dealing with partial functions), we
    let the state be defined for _all_ variables, even though any
    given program is only going to mention a finite number of them. *)

Definition state := id -> nat.

Definition empty_state : state :=
  fun _ => 0.

Definition update (st : state) (x : id) (n : nat) : state :=
  fun x' => if eq_id_dec x x' then n else st x'.

(** For proofs involving states, we'll need several simple properties
    of [update]. *)

(** **** Exercise: 1 star (update_eq) *)
Theorem update_eq : forall n x st,
  (update st x n) x = n.
Proof.
  intros. unfold update. apply eq_id.
Qed.
  (* FILL IN HERE *)
(** [] *)

(** **** Exercise: 1 star (update_neq) *)
Theorem update_neq : forall x2 x1 n st,
  x2 <> x1 ->                        
  (update st x2 n) x1 = (st x1).
Proof.
  intros.
  unfold update. apply neq_id. apply H.
Qed.
  (* FILL IN HERE *) 
(** [] *)

(** **** Exercise: 1 star (update_example) *)
(** Before starting to play with tactics, make sure you understand
    exactly what the theorem is saying! *)

Theorem update_example : forall (n:nat),
  (update empty_state (Id 2) n) (Id 3) = 0.
Proof.
  intros. unfold update. simpl. reflexivity.
Qed.
  (* FILL IN HERE *)
(** [] *)

(** **** Exercise: 1 star (update_shadow) *)
Theorem update_shadow : forall n1 n2 x1 x2 (st : state),
   (update  (update st x2 n1) x2 n2) x1 = (update st x2 n2) x1.
Proof.
  intros. 
  unfold update. destruct (eq_id_dec x2 x1).
  Case "x2=x1". reflexivity.
  Case "x2<>x1". reflexivity.
Qed.
  (* FILL IN HERE *)
(** [] *)

(** **** Exercise: 2 stars (update_same) *)
Theorem update_same : forall n1 x1 x2 (st : state),
  st x1 = n1 ->
  (update st x1 n1) x2 = st x2.
Proof.
  intros.
  unfold update. destruct (eq_id_dec x1 x2).
  Case "x1=x2". rewrite<-e. rewrite->H. reflexivity.
  Case "x1<>x2". reflexivity.
Qed.
  (* FILL IN HERE *)
(** [] *)

(** **** Exercise: 3 stars (update_permute) *)
Theorem update_permute : forall n1 n2 x1 x2 x3 st,
  x2 <> x1 -> 
  (update (update st x2 n1) x1 n2) x3 = (update (update st x1 n2) x2 n1) x3.
Proof.
  intros. 
  unfold update. destruct (eq_id_dec x1 x3).
  Case "x1=x3". destruct (eq_id_dec x2 x3).
    SCase "x2=x3". apply ex_falso_quodlibet. apply H. rewrite->e.
                   rewrite->e0. reflexivity.
    SCase "x2<>x3". reflexivity.
  Case "x1<>x3". destruct (eq_id_dec x2 x3).
    SCase "x2=x3". reflexivity.
    SCase "x2<>X3". reflexivity.
Qed.
  (* FILL IN HERE *)
(** [] *)

(* ################################################### *)
(** ** Syntax  *)

(** We can add variables to the arithmetic expressions we had before by
    simply adding one more constructor: *)

Inductive aexp : Type :=
  | ANum : nat -> aexp
  | AId : id -> aexp                (* <----- NEW *)
  | APlus : aexp -> aexp -> aexp
  | AMinus : aexp -> aexp -> aexp
  | AMult : aexp -> aexp -> aexp.

Tactic Notation "aexp_cases" tactic(first) ident(c) :=
  first;
  [ Case_aux c "ANum" | Case_aux c "AId" | Case_aux c "APlus"
  | Case_aux c "AMinus" | Case_aux c "AMult" ].

(** Defining a few variable names as notational shorthands will make
    examples easier to read: *)

Definition X : id := Id 0.
Definition Y : id := Id 1.
Definition Z : id := Id 2.

(** (This convention for naming program variables ([X], [Y],
    [Z]) clashes a bit with our earlier use of uppercase letters for
    types.  Since we're not using polymorphism heavily in this part of
    the course, this overloading should not cause confusion.) *)

(** The definition of [bexp]s is the same as before (using the new
    [aexp]s): *)

Inductive bexp : Type :=
  | BTrue : bexp
  | BFalse : bexp
  | BEq : aexp -> aexp -> bexp
  | BLe : aexp -> aexp -> bexp
  | BNot : bexp -> bexp
  | BAnd : bexp -> bexp -> bexp.

Tactic Notation "bexp_cases" tactic(first) ident(c) :=
  first;
  [ Case_aux c "BTrue" | Case_aux c "BFalse" | Case_aux c "BEq"
  | Case_aux c "BLe" | Case_aux c "BNot" | Case_aux c "BAnd" ].

(* ################################################### *)
(** ** Evaluation  *)

(** The arith and boolean evaluators can be extended to handle
    variables in the obvious way: *)

Fixpoint aeval (st : state) (a : aexp) : nat :=
  match a with
  | ANum n => n
  | AId x => st x                                        (* <----- NEW *)
  | APlus a1 a2 => (aeval st a1) + (aeval st a2)
  | AMinus a1 a2  => (aeval st a1) - (aeval st a2)
  | AMult a1 a2 => (aeval st a1) * (aeval st a2)
  end.

Fixpoint beval (st : state) (b : bexp) : bool :=
  match b with
  | BTrue       => true
  | BFalse      => false
  | BEq a1 a2   => beq_nat (aeval st a1) (aeval st a2)
  | BLe a1 a2   => ble_nat (aeval st a1) (aeval st a2)
  | BNot b1     => negb (beval st b1)
  | BAnd b1 b2  => andb (beval st b1) (beval st b2)
  end.

Example aexp1 :
  aeval (update empty_state X 5)
        (APlus (ANum 3) (AMult (AId X) (ANum 2)))
  = 13.
Proof. reflexivity. Qed.

Example bexp1 :
  beval (update empty_state X 5)
        (BAnd BTrue (BNot (BLe (AId X) (ANum 4))))
  = true.
Proof. reflexivity. Qed.

(* ####################################################### *)
(** * Commands *)

(** Now we are ready define the syntax and behavior of Imp
    _commands_ (often called _statements_). *)

(* ################################################### *)
(** ** Syntax *)

(** Informally, commands [c] are described by the following BNF
    grammar:
     c ::= SKIP
         | x ::= a
         | c ; c
         | WHILE b DO c END
         | IFB b THEN c ELSE c FI
    For example, here's the factorial function in Imp.
     Z ::= X;
     Y ::= 1;
     WHILE not (Z = 0) DO
       Y ::= Y * Z;
       Z ::= Z - 1
     END
   When this command terminates, the variable [Y] will contain the
   factorial of the initial value of [X].
*)

(** Here is the formal definition of the syntax of commands: *)

Inductive com : Type :=
  | CSkip : com
  | CAss : id -> aexp -> com
  | CSeq : com -> com -> com
  | CIf : bexp -> com -> com -> com
  | CWhile : bexp -> com -> com.

Tactic Notation "com_cases" tactic(first) ident(c) :=
  first;
  [ Case_aux c "SKIP" | Case_aux c "::=" | Case_aux c ";;"
  | Case_aux c "IFB" | Case_aux c "WHILE" ].

(** As usual, we can use a few [Notation] declarations to make things
    more readable.  We need to be a bit careful to avoid conflicts
    with Coq's built-in notations, so we'll keep this light -- in
    particular, we won't introduce any notations for [aexps] and
    [bexps] to avoid confusion with the numerical and boolean
    operators we've already defined.  We use the keyword [IFB] for
    conditionals instead of [IF], for similar reasons. *)

Notation "'SKIP'" :=
  CSkip.
Notation "x '::=' a" :=
  (CAss x a) (at level 60).
Notation "c1 ;; c2" :=
  (CSeq c1 c2) (at level 80, right associativity).
Notation "'WHILE' b 'DO' c 'END'" :=
  (CWhile b c) (at level 80, right associativity).
Notation "'IFB' c1 'THEN' c2 'ELSE' c3 'FI'" :=
  (CIf c1 c2 c3) (at level 80, right associativity).

(** For example, here is the factorial function again, written as a
    formal definition to Coq: *)

Definition fact_in_coq : com :=
  Z ::= AId X;;
  Y ::= ANum 1;;
  WHILE BNot (BEq (AId Z) (ANum 0)) DO
    Y ::= AMult (AId Y) (AId Z);;
    Z ::= AMinus (AId Z) (ANum 1)
  END.

(* ####################################################### *)
(** ** Examples *)

(** Assignment: *)

Definition plus2 : com :=
  X ::= (APlus (AId X) (ANum 2)).

Definition XtimesYinZ : com :=
  Z ::= (AMult (AId X) (AId Y)).

Definition subtract_slowly_body : com :=
  Z ::= AMinus (AId Z) (ANum 1) ;;
  X ::= AMinus (AId X) (ANum 1).

(** Loops: *)

Definition subtract_slowly : com :=
  WHILE BNot (BEq (AId X) (ANum 0)) DO
    subtract_slowly_body
  END.

Definition subtract_3_from_5_slowly : com :=
  X ::= ANum 3 ;;
  Z ::= ANum 5 ;;
  subtract_slowly.

(** An infinite loop: *)

Definition loop : com :=
  WHILE BTrue DO
    SKIP
  END.

(* ################################################################ *)
(** * Evaluation *)

(** Next we need to define what it means to evaluate an Imp command.
    The fact that [WHILE] loops don't necessarily terminate makes defining
    an evaluation function tricky... *)

(* #################################### *)
(** ** Evaluation as a Function (Failed Attempt) *)

(** Here's an attempt at defining an evaluation function for commands,
    omitting the [WHILE] case. *)

Fixpoint ceval_fun_no_while (st : state) (c : com) : state :=
  match c with
    | SKIP =>
        st
    | x ::= a1 =>
        update st x (aeval st a1)
    | c1 ;; c2 =>
        let st' := ceval_fun_no_while st c1 in
        ceval_fun_no_while st' c2
    | IFB b THEN c1 ELSE c2 FI =>
        if (beval st b)
          then ceval_fun_no_while st c1
          else ceval_fun_no_while st c2
    | WHILE b DO c END =>
        st  (* bogus *)
  end.

(** In a traditional functional programming language like ML or
    Haskell we could write the [WHILE] case as follows:
<<
  Fixpoint ceval_fun (st : state) (c : com) : state :=
    match c with
      ...
      | WHILE b DO c END =>
          if (beval st b1)
            then ceval_fun st (c1; WHILE b DO c END)
            else st
    end.
>>
    Coq doesn't accept such a definition ("Error: Cannot guess
    decreasing argument of fix") because the function we want to
    define is not guaranteed to terminate. Indeed, it doesn't always
    terminate: for example, the full version of the [ceval_fun]
    function applied to the [loop] program above would never
    terminate. Since Coq is not just a functional programming
    language, but also a consistent logic, any potentially
    non-terminating function needs to be rejected. Here is
    an (invalid!) Coq program showing what would go wrong if Coq
    allowed non-terminating recursive functions:
<<
     Fixpoint loop_false (n : nat) : False := loop_false n.
>>
    That is, propositions like [False] would become provable
    (e.g. [loop_false 0] would be a proof of [False]), which
    would be a disaster for Coq's logical consistency.

    Thus, because it doesn't terminate on all inputs, the full version
    of [ceval_fun] cannot be written in Coq -- at least not without
    additional tricks (see chapter [ImpCEvalFun] if curious). *)

(* #################################### *)
(** ** Evaluation as a Relation *)

(** Here's a better way: we define [ceval] as a _relation_ rather than
    a _function_ -- i.e., we define it in [Prop] instead of [Type], as
    we did for [aevalR] above. *)

(** This is an important change.  Besides freeing us from the awkward
    workarounds that would be needed to define evaluation as a
    function, it gives us a lot more flexibility in the definition.
    For example, if we added concurrency features to the language,
    we'd want the definition of evaluation to be non-deterministic --
    i.e., not only would it not be total, it would not even be a
    partial function! *)

(** We'll use the notation [c / st || st'] for our [ceval] relation:
    [c / st || st'] means that executing program [c] in a starting
    state [st] results in an ending state [st'].  This can be
    pronounced "[c] takes state [st] to [st']".
                           ----------------                            (E_Skip)
                           SKIP / st || st

                           aeval st a1 = n
                   --------------------------------                     (E_Ass)
                   x := a1 / st || (update st x n)

                           c1 / st || st'
                          c2 / st' || st''
                         -------------------                            (E_Seq)
                         c1;;c2 / st || st''

                          beval st b1 = true
                           c1 / st || st'
                -------------------------------------                (E_IfTrue)
                IF b1 THEN c1 ELSE c2 FI / st || st'

                         beval st b1 = false
                           c2 / st || st'
                -------------------------------------               (E_IfFalse)
                IF b1 THEN c1 ELSE c2 FI / st || st'

                         beval st b1 = false
                    ------------------------------                 (E_WhileEnd)
                    WHILE b DO c END / st || st

                          beval st b1 = true
                           c / st || st'
                  WHILE b DO c END / st' || st''
                  ---------------------------------               (E_WhileLoop)
                    WHILE b DO c END / st || st''
*)

(** Here is the formal definition.  (Make sure you understand
    how it corresponds to the inference rules.) *)

Reserved Notation "c1 '/' st '||' st'" (at level 40, st at level 39).

Inductive ceval : com -> state -> state -> Prop :=
  | E_Skip : forall st,
      SKIP / st || st
  | E_Ass  : forall st a1 n x,
      aeval st a1 = n ->
      (x ::= a1) / st || (update st x n)
  | E_Seq : forall c1 c2 st st' st'',
      c1 / st  || st' ->
      c2 / st' || st'' ->
      (c1 ;; c2) / st || st''
  | E_IfTrue : forall st st' b c1 c2,
      beval st b = true ->
      c1 / st || st' ->
      (IFB b THEN c1 ELSE c2 FI) / st || st'
  | E_IfFalse : forall st st' b c1 c2,
      beval st b = false ->
      c2 / st || st' ->
      (IFB b THEN c1 ELSE c2 FI) / st || st'
  | E_WhileEnd : forall b st c,
      beval st b = false ->
      (WHILE b DO c END) / st || st
  | E_WhileLoop : forall st st' st'' b c,
      beval st b = true ->
      c / st || st' ->
      (WHILE b DO c END) / st' || st'' ->
      (WHILE b DO c END) / st || st''

  where "c1 '/' st '||' st'" := (ceval c1 st st').

Tactic Notation "ceval_cases" tactic(first) ident(c) :=
  first;
  [ Case_aux c "E_Skip" | Case_aux c "E_Ass" | Case_aux c "E_Seq"
  | Case_aux c "E_IfTrue" | Case_aux c "E_IfFalse"
  | Case_aux c "E_WhileEnd" | Case_aux c "E_WhileLoop" ].

(** The cost of defining evaluation as a relation instead of a
    function is that we now need to construct _proofs_ that some
    program evaluates to some result state, rather than just letting
    Coq's computation mechanism do it for us. *)

Example ceval_example1:
    (X ::= ANum 2;;
     IFB BLe (AId X) (ANum 1)
       THEN Y ::= ANum 3
       ELSE Z ::= ANum 4
     FI)
   / empty_state
   || (update (update empty_state X 2) Z 4).
Proof.
  (* We must supply the intermediate state *)
  apply E_Seq with (update empty_state X 2).
  Case "assignment command".
    apply E_Ass. reflexivity.
  Case "if command".
    apply E_IfFalse.
      reflexivity.
      apply E_Ass. reflexivity.  Qed.

(** **** Exercise: 2 stars (ceval_example2) *)
Example ceval_example2:
    (X ::= ANum 0;; Y ::= ANum 1;; Z ::= ANum 2) / empty_state ||
    (update (update (update empty_state X 0) Y 1) Z 2).
Proof.
  apply E_Seq with (update empty_state X 0).
  Case "x::=ANum 0". apply E_Ass. reflexivity.
  Case ";;". apply E_Seq with (update (update empty_state X 0) Y 1).
    SCase "Y::=ANum 1". apply E_Ass. reflexivity.
    SCase "Z::=ANum 2". apply E_Ass. reflexivity.
Qed.
  (* FILL IN HERE *) 
(** [] *)

(** **** Exercise: 3 stars, advanced (pup_to_n) *)
(** Write an Imp program that sums the numbers from [1] to
   [X] (inclusive: [1 + 2 + ... + X]) in the variable [Y].
   Prove that this program executes as intended for X = 2
   (this latter part is trickier than you might expect). *)

Definition pup_to_n : com :=
   Y::=ANum 0;;
   WHILE BNot(BLe (AId X) (ANum 0)) DO
     Y::=APlus (AId Y) (AId X);;
     X::=AMinus (AId X) (ANum 1)
   END.
  (* FILL IN HERE *) 

Theorem pup_to_2_ceval :
  pup_to_n / (update empty_state X 2) ||
    update (update (update (update (update (update empty_state
      X 2) Y 0) Y 2) X 1) Y 3) X 0.
Proof.
  apply E_Seq with (update (update empty_state X 2) Y 0).
  Case "Y::=ANum 0". apply E_Ass. reflexivity.
  Case "WHILE". 
   apply E_WhileLoop with (update (update (update (update empty_state X 2) Y 0) Y 2) X 1).
   SCase "beval st b = true ". simpl. reflexivity.
   SCase "c / st || st'".
    apply E_Seq with (update (update (update empty_state X 2) Y 0) Y 2).
    SSCase ";;". apply E_Ass. simpl. reflexivity. apply E_Ass. simpl. reflexivity.
   apply E_WhileLoop with (update (update (update (update (update (update empty_state
      X 2) Y 0) Y 2) X 1) Y 3) X 0).
   SCase "beval st b = true ". simpl. reflexivity.
   SCase "c / st || st'".
    apply E_Seq with (update (update (update (update (update empty_state X 2) 
                           Y 0) Y 2) X 1) Y 3).
    SSCase ";;". apply E_Ass. simpl. reflexivity. apply E_Ass. reflexivity.
  apply E_WhileEnd. simpl. reflexivity.
Qed.
    
  (* FILL IN HERE *)
(** [] *)


(* ####################################################### *)
(** ** Determinism of Evaluation *)

(** Changing from a computational to a relational definition of
    evaluation is a good move because it allows us to escape from the
    artificial requirement (imposed by Coq's restrictions on
    [Fixpoint] definitions) that evaluation should be a total
    function.  But it also raises a question: Is the second definition
    of evaluation actually a partial function?  That is, is it
    possible that, beginning from the same state [st], we could
    evaluate some command [c] in different ways to reach two different
    output states [st'] and [st'']?

    In fact, this cannot happen: [ceval] is a partial function.
    Here's the proof: *)

Theorem ceval_deterministic: forall c st st1 st2,
     c / st || st1  ->
     c / st || st2 ->
     st1 = st2.
Proof.
  intros c st st1 st2 E1 E2.
  generalize dependent st2.
  ceval_cases (induction E1) Case;
           intros st2 E2; inversion E2; subst.
  Case "E_Skip". reflexivity.
  Case "E_Ass". reflexivity.
  Case "E_Seq".
    assert (st' = st'0) as EQ1.
      SCase "Proof of assertion". apply IHE1_1; assumption.
    subst st'0.
    apply IHE1_2. assumption.
  Case "E_IfTrue".
    SCase "b1 evaluates to true".
      apply IHE1. assumption.
    SCase "b1 evaluates to false (contradiction)".
      rewrite H in H5. inversion H5.
  Case "E_IfFalse".
    SCase "b1 evaluates to true (contradiction)".
      rewrite H in H5. inversion H5.
    SCase "b1 evaluates to false".
      apply IHE1. assumption.
  Case "E_WhileEnd".
    SCase "b1 evaluates to false".
      reflexivity.
    SCase "b1 evaluates to true (contradiction)".
      rewrite H in H2. inversion H2.
  Case "E_WhileLoop".
    SCase "b1 evaluates to false (contradiction)".
      rewrite H in H4. inversion H4.
    SCase "b1 evaluates to true".
      assert (st' = st'0) as EQ1.
        SSCase "Proof of assertion". apply IHE1_1; assumption.
      subst st'0.
      apply IHE1_2. assumption.  Qed.

(* ####################################################### *)
(** * Reasoning About Imp Programs *)

(** We'll get much deeper into systematic techniques for reasoning
    about Imp programs in the following chapters, but we can do quite
    a bit just working with the bare definitions. *)

(* This section explores some examples. *)

Theorem plus2_spec : forall st n st',
  st X = n ->
  plus2 / st || st' ->
  st' X = n + 2.
Proof.
  intros st n st' HX Heval.
  (* Inverting Heval essentially forces Coq to expand one
     step of the ceval computation - in this case revealing
     that st' must be st extended with the new value of X,
     since plus2 is an assignment *)
  inversion Heval. subst.  clear Heval. simpl. 
  apply update_eq.  Qed.

(** **** Exercise: 3 stars (XtimesYinZ_spec) *)
(** State and prove a specification of [XtimesYinZ]. *)
Theorem XtimesYinZ_spec : forall st st' n m,
  st X = n->
  st Y = m ->
  XtimesYinZ / st || st' ->
  st' Z = n * m.
Proof.
  intros st st' n m HX HY HCOM.
  inversion HCOM. rewrite<-H3. simpl. rewrite->HX. rewrite->HY. 
  apply update_eq.
Qed.
   
(* FILL IN HERE *)
(** [] *)

(** **** Exercise: 3 stars (loop_never_stops) *)
Theorem loop_never_stops : forall st st',
  ~(loop / st || st').
Proof.
  intros st st' contra. unfold loop in contra.
  remember (WHILE BTrue DO SKIP END) as loopdef eqn:Heqloopdef.
    (* Proceed by induction on the assumed derivation showing that
     [loopdef] terminates.  Most of the cases are immediately
     contradictory (and so can be solved in one step with
     [inversion]). *)
   induction contra; try inversion Heqloopdef.
   Case "loopdef=(WHILE false)". rewrite->H1 in H. inversion H.
   Case "loopdef=(WHILE true)". apply IHcontra2.  apply Heqloopdef.
  (*induction contra. 
  Case "loopdef=Skip". inversion Heqloopdef.
  Case "loopdef=(x::=a1)". inversion Heqloopdef.
  Case "loopdef=(c1;;c2)". inversion Heqloopdef.
  Case "loopdef=(IFB. true..)". inversion Heqloopdef.
  Case "loopdef=(IFB.false..)". inversion Heqloopdef.
  Case "loopdef=(WHILE false)". inversion Heqloopdef.             
                         rewrite->H1 in H. inversion H.
  Case "loopdef=(WHILE true)". apply IHcontra2.  apply Heqloopdef.*)
Qed.
 
  (* FILL IN HERE *)
(** [] *)

(** **** Exercise: 3 stars (no_whilesR) *)
(** Consider the definition of the [no_whiles] property below: *)

Fixpoint no_whiles (c : com) : bool :=
  match c with
  | SKIP       => true
  | _ ::= _    => true
  | c1 ;; c2  => andb (no_whiles c1) (no_whiles c2)
  | IFB _ THEN ct ELSE cf FI => andb (no_whiles ct) (no_whiles cf)
  | WHILE _ DO _ END  => false
  end.

(** This property yields [true] just on programs that
    have no while loops.  Using [Inductive], write a property
    [no_whilesR] such that [no_whilesR c] is provable exactly when [c]
    is a program with no while loops.  Then prove its equivalence
    with [no_whiles]. *)

Inductive no_whilesR: com -> Prop :=
  |R_SKIP: no_whilesR SKIP
  |R_ASS : forall x a1, no_whilesR (x::=a1)
  |R_SQE : forall (c1 c2 : com), no_whilesR c1 ->
          no_whilesR c2 -> no_whilesR (c1;;c2)
  |R_IF  : forall (c1 c2 : com) b, no_whilesR c1 ->
          no_whilesR c2 -> no_whilesR (IFB b THEN c1 ELSE c2 FI).

 (* FILL IN HERE *)

Theorem no_whiles_eqv:
   forall c, no_whiles c = true <-> no_whilesR c.
Proof.
  split. 
  Case "->". intro. induction c.
    SCase "SKIP". apply R_SKIP.
    SCase "ASS". apply R_ASS.
    SCase "SQE". inversion H. apply andb_true in H1. inversion H1 as [HC1 HC2]. 
                 apply R_SQE. apply IHc1.  apply HC1. apply IHc2. apply HC2.
    SCase "IF".  inversion H. apply andb_true in H1. inversion H1 as [HC1 HC2].
                 apply R_IF. apply IHc1. apply HC1. apply IHc2. apply HC2.
    SCase "WHILE". inversion H.
  Case "<-". intro. induction c.
    SCase "SKIP". simpl. reflexivity.
    SCase "ASS". simpl. reflexivity.
    SCase "SQE". inversion H. simpl. apply IHc1 in H2. apply IHc2 in H3.
                  rewrite->H2. rewrite->H3. reflexivity.
    SCase "IF". inversion H. simpl. apply IHc1 in H2. apply IHc2 in H4.
                  rewrite->H2. rewrite->H4. reflexivity.
    SCase "WHILE". inversion H.
Qed.
  (* FILL IN HERE *)
(** [] *)

(** **** Exercise: 4 stars (no_whiles_terminating) *)
(** Imp programs that don't involve while loops always terminate.
    State and prove a theorem that says this. *)
(** (Use either [no_whiles] or [no_whilesR], as you prefer.) *)
Theorem no_whiles_terminating : 
  forall (c:com), no_whilesR c -> forall (st:state), exists st', c/st||st'.
Proof.
  intros c. induction c.
  Case "SKIP". intros. exists st. apply E_Skip.
  Case "ASS". intros. exists (update st i (aeval st a)). apply E_Ass. reflexivity.
  Case "SQE". intros. inversion H. remember (IHc1 H2 st). inversion e.
                                   remember (IHc2 H3 x). inversion e0.  exists x0.
                                   apply (E_Seq c1 c2 st x x0). apply H4. apply H5.
  Case "IF". intros. inversion H. remember (beval st b). destruct b1.
     SCase "beval st b = true". remember (IHc1 H2 st). inversion e. exists x.
                                apply E_IfTrue. rewrite<-H0. rewrite->H0.
                                rewrite->Heqb1. reflexivity. apply H5.
     SCase "beval st b = false". remember (IHc2 H4 st). inversion e. exists x.
                                 apply E_IfFalse. rewrite<-H0. rewrite->H0.
                                 rewrite->Heqb1. reflexivity. apply H5.
  Case "WHILE". intros. inversion H.
Qed.

(* FILL IN HERE *)
(** [] *)

(* ####################################################### *)
(** * Additional Exercises *)

(** **** Exercise: 3 stars (stack_compiler) *)
(** HP Calculators, programming languages like Forth and Postscript,
    and abstract machines like the Java Virtual Machine all evaluate
    arithmetic expressions using a stack. For instance, the expression
<<
   (2*3)+(3*(4-2))
>>
   would be entered as
<<
   2 3 * 3 4 2 - * +
>>
   and evaluated like this:
<<
  []            |    2 3 * 3 4 2 - * +
  [2]           |    3 * 3 4 2 - * +
  [3, 2]        |    * 3 4 2 - * +
  [6]           |    3 4 2 - * +
  [3, 6]        |    4 2 - * +
  [4, 3, 6]     |    2 - * +
  [2, 4, 3, 6]  |    - * +
  [2, 3, 6]     |    * +
  [6, 6]        |    +
  [12]          |
>>

  The task of this exercise is to write a small compiler that
  translates [aexp]s into stack machine instructions.

  The instruction set for our stack language will consist of the
  following instructions:
     - [SPush n]: Push the number [n] on the stack.
     - [SLoad x]: Load the identifier [x] from the store and push it
                  on the stack
     - [SPlus]:   Pop the two top numbers from the stack, add them, and
                  push the result onto the stack.
     - [SMinus]:  Similar, but subtract.
     - [SMult]:   Similar, but multiply. *)

Inductive sinstr : Type :=
| SPush : nat -> sinstr
| SLoad : id -> sinstr
| SPlus : sinstr
| SMinus : sinstr
| SMult : sinstr.

(** Write a function to evaluate programs in the stack language. It
    takes as input a state, a stack represented as a list of
    numbers (top stack item is the head of the list), and a program
    represented as a list of instructions, and returns the stack after
    executing the program. Test your function on the examples below.

    Note that the specification leaves unspecified what to do when
    encountering an [SPlus], [SMinus], or [SMult] instruction if the
    stack contains less than two elements.  In a sense, it is
    immaterial what we do, since our compiler will never emit such a
    malformed program. *)

Fixpoint s_execute (st : state) (stack : list nat)
                   (prog : list sinstr)
                 : list nat := 
 match prog with
  |[]=>stack
  |h::t=> match h with
           |SPush n => s_execute st (n::stack) t
           |SLoad X => s_execute st ((st X)::stack) t
           |SPlus => match stack with 
                     |[]=>[]
                     |[x]=>[]
                     |h1::h2::s => s_execute st ((h1+h2)::s) t
                     end
           |SMinus=>match stack with
                     |[]=>[]
                     |[x]=>[]
                     |h1::h2::s=> s_execute st ((h2-h1)::s) t
                    end
           |SMult=> match stack with
                     |[]=>[]
                     |[x]=>[]
                     |h1::h2::s=> s_execute st ((h2*h1)::s) t
                    end
          end 
 end.
(* FILL IN HERE *)

Example s_execute1 :
     s_execute empty_state []
       [SPush 5; SPush 3; SPush 1; SMinus]
   = [2; 5].
Proof. simpl. reflexivity. Qed.
(* FILL IN HERE *) 

Example s_execute2 :
     s_execute (update empty_state X 3) [3;4]
       [SPush 4; SLoad X; SMult; SPlus]
   = [15; 4].
Proof. simpl. reflexivity. Qed.
(* FILL IN HERE *)

(** Next, write a function which compiles an [aexp] into a stack
    machine program. The effect of running the program should be the
    same as pushing the value of the expression on the stack. *)

Fixpoint s_compile (e : aexp) : list sinstr :=
 match e with
 |ANum n => [SPush n]
 |AId X => [SLoad X] 
 |APlus e1 e2 =>(s_compile e1) ++ (s_compile e2)++[SPlus]
 |AMinus e1 e2 => (s_compile e1) ++ (s_compile e2)++[SMinus]
 |AMult e1 e2 => (s_compile e1) ++ (s_compile e2)++[SMult]
 end.
(* FILL IN HERE *) 

(** After you've defined [s_compile], uncomment the following to test
    that it works. *)


Example s_compile1 :
    s_compile (AMinus (AId X) (AMult (ANum 2) (AId Y)))
  = [SLoad X; SPush 2; SLoad Y; SMult; SMinus].
Proof. reflexivity. Qed.

(** [] *)

(** **** Exercise: 3 stars, advanced (stack_compiler_correct) *)
(** The task of this exercise is to prove the correctness of the
    calculator implemented in the previous exercise.  Remember that
    the specification left unspecified what to do when encountering an
    [SPlus], [SMinus], or [SMult] instruction if the stack contains
    less than two elements.  (In order to make your correctness proof
    easier you may find it useful to go back and change your
    implementation!)

    Prove the following theorem, stating that the [compile] function
    behaves correctly.  You will need to start by stating a more
    general lemma to get a usable induction hypothesis; the main
    theorem will then be a simple corollary of this lemma. *)


Theorem s_execute_stack : forall (st : state) (prog : list sinstr) (stack stack' stack'' : list nat),
  s_execute st stack prog = stack'' ->
  stack'' <> [] ->
  s_execute st (stack ++ stack') prog = (stack'' ++ stack').
Proof.
  induction prog.
  Case "prog=[]". intros. inversion H; subst; auto.
  Case "prog=a::prog". intros. destruct a. 
    SCase "SPush n :: prog". simpl. inversion H. subst. clear H1.
                apply (IHprog (n :: stack) stack'); auto.
    SCase "SLoad i :: prog". simpl. inversion H. subst. clear H1.
                apply (IHprog ((st i) :: stack) stack'); auto.
    SCase "SPlus :: prog". simpl. inversion H. subst. clear H1.
                destruct stack; simpl in H0.  apply ex_falso_quodlibet; apply H0; auto.
                destruct stack; simpl in H0. apply ex_falso_quodlibet; apply H0; auto. simpl.
                apply (IHprog (n + n0 :: stack) stack' (s_execute st (n + n0 :: stack) prog)); auto.
    SCase "SMinus :: prog". simpl. inversion H. subst. clear H1.
                destruct stack; simpl in H0. apply ex_falso_quodlibet; apply H0; auto.
                destruct stack; simpl in H0.
                apply ex_falso_quodlibet; apply H0; auto. simpl.
                apply (IHprog (n0 - n :: stack) stack' (s_execute st (n0 - n :: stack) prog)); auto.
    SCase "SMult :: prog". simpl. inversion H. subst. clear H1.
                destruct stack; simpl in H0.
                apply ex_falso_quodlibet; apply H0; auto.
                destruct stack; simpl in H0.
                apply ex_falso_quodlibet; apply H0; auto.  simpl.
                apply (IHprog (n0 * n :: stack) stack' (s_execute st (n0 * n :: stack) prog)); auto.  
Qed.
  
Theorem s_execute_app : forall (st : state) (l1 l2 : list sinstr) (stack stack' stack'' : list nat),
  s_execute st stack l1 = stack' ->
  s_execute st stack' l2 = stack'' ->
  stack' <> [] ->
  s_execute st stack (l1 ++ l2) = stack''.
Proof.
  induction l1. (* ; intros; simpl; auto.*)
  Case "[]". intros; simpl; auto.
        inversion H; subst; simpl; auto.
  Case "a :: l1". intros; simpl; auto. destruct a.
    SCase "SPush n :: prog". inversion H; subst; simpl.
        apply (IHl1 l2 (n :: stack) (s_execute st (n :: stack) l1)); auto.
    SCase "SLoad i :: prog". inversion H; subst; simpl.
        apply (IHl1 l2 (st i :: stack) (s_execute st (st i :: stack) l1)); auto.
    SCase "SPlus :: prog". destruct stack.
        inversion H; subst; simpl.
        apply ex_falso_quodlibet; apply H1; auto.
        destruct stack.
        inversion H; subst; simpl.
        apply ex_falso_quodlibet; apply H1; auto.
        inversion H; subst; simpl.
        apply (IHl1 l2 (n + n0 :: stack) (s_execute st (n + n0 :: stack) l1)); auto.
    SCase "SMinus :: prog". destruct stack.
        inversion H; subst; simpl.
        apply ex_falso_quodlibet; apply H1; auto.
        destruct stack.
        inversion H; subst; simpl.
        apply ex_falso_quodlibet; apply H1; auto.
        inversion H; subst; simpl.
        apply (IHl1 l2 (n0 - n :: stack) (s_execute st (n0 - n :: stack) l1)); auto.
    SCase "SMult :: prog".  destruct stack.
        inversion H; subst; simpl.
        apply ex_falso_quodlibet; apply H1; auto.
        destruct stack.
        inversion H; subst; simpl.
        apply ex_falso_quodlibet; apply H1; auto.
        inversion H; subst; simpl.
        apply (IHl1 l2 (n0 * n :: stack) (s_execute st (n0 * n :: stack) l1)); auto.
Qed.

Theorem s_compile_correct : forall (st : state) (e : aexp),
  s_execute st [] (s_compile e) = [ aeval st e ].
Proof. 
  induction e.
  Case "ANum n". simpl. auto.
  Case "AId i". simpl. auto.
  Case "APlus e1 e2". simpl.   
     rewrite (s_execute_app st (s_compile e1) 
          (s_compile e2 ++ [SPlus]) [] [aeval st e1] [aeval st e1 + aeval st e2]);auto.
     rewrite (s_execute_app st (s_compile e2) 
          [SPlus] [aeval st e1] [aeval st e2;aeval st e1] [aeval st e1 + aeval st e2]); auto.
     apply (s_execute_stack st (s_compile e2) [] [aeval st e1] [aeval st e2]).
     auto. intro. inversion H. simpl. rewrite->plus_comm. reflexivity.
     intro. inversion H. intro. inversion H.
  Case "AMinus e1 e2". simpl.
     rewrite (s_execute_app st (s_compile e1) 
         (s_compile e2 ++ [SMinus]) [] [aeval st e1] [aeval st e1 - aeval st e2]); auto.
     rewrite (s_execute_app st (s_compile e2)
         [SMinus] [aeval st e1] [aeval st e2; aeval st e1] [aeval st e1 - aeval st e2]); auto.
     apply (s_execute_stack st (s_compile e2) [] [aeval st e1] [aeval st e2]).
     auto. intro; inversion H. intro; inversion H. intro; inversion H.
  Case "AMult e1 e2". simpl.
     rewrite (s_execute_app st (s_compile e1) (s_compile e2 ++ [SMult]) [] [aeval st e1] [aeval st e1 * aeval st e2]); auto.
     rewrite (s_execute_app st (s_compile e2) [SMult] [aeval st e1] [aeval st e2; aeval st e1] [aeval st e1 * aeval st e2]); auto.
     apply (s_execute_stack st (s_compile e2) [] [aeval st e1] [aeval st e2]).
     auto. intro; inversion H. intro; inversion H. intro; inversion H.
Qed.
  (* FILL IN HERE*) 
(** [] *)

(** **** Exercise: 5 stars, advanced (break_imp) *)
Module BreakImp.

(** Imperative languages such as C or Java often have a [break] or
    similar statement for interrupting the execution of loops. In this
    exercise we will consider how to add [break] to Imp.

    First, we need to enrich the language of commands with an
    additional case. *)

Inductive com : Type :=
  | CSkip : com
  | CBreak : com
  | CAss : id -> aexp -> com
  | CSeq : com -> com -> com
  | CIf : bexp -> com -> com -> com
  | CWhile : bexp -> com -> com.

Tactic Notation "com_cases" tactic(first) ident(c) :=
  first;
  [ Case_aux c "SKIP" | Case_aux c "BREAK" | Case_aux c "::=" | Case_aux c ";"
  | Case_aux c "IFB" | Case_aux c "WHILE" ].

Notation "'SKIP'" :=
  CSkip.
Notation "'BREAK'" :=
  CBreak.
Notation "x '::=' a" :=
  (CAss x a) (at level 60).
Notation "c1 ; c2" :=
  (CSeq c1 c2) (at level 80, right associativity).
Notation "'WHILE' b 'DO' c 'END'" :=
  (CWhile b c) (at level 80, right associativity).
Notation "'IFB' c1 'THEN' c2 'ELSE' c3 'FI'" :=
  (CIf c1 c2 c3) (at level 80, right associativity).

(** Next, we need to define the behavior of [BREAK].  Informally,
    whenever [BREAK] is executed in a sequence of commands, it stops
    the execution of that sequence and signals that the innermost
    enclosing loop (if any) should terminate. If there aren't any
    enclosing loops, then the whole program simply terminates. The
    final state should be the same as the one in which the [BREAK]
    statement was executed.

    One important point is what to do when there are multiple loops
    enclosing a given [BREAK]. In those cases, [BREAK] should only
    terminate the _innermost_ loop where it occurs. Thus, after
    executing the following piece of code...
   X ::= 0;
   Y ::= 1;
   WHILE 0 <> Y DO
     WHILE TRUE DO
       BREAK
     END;
     X ::= 1;
     Y ::= Y - 1
   END
    ... the value of [X] should be [1], and not [0].

    One way of expressing this behavior is to add another parameter to
    the evaluation relation that specifies whether evaluation of a
    command executes a [BREAK] statement: *)

Inductive status : Type :=
  | SContinue : status
  | SBreak : status.

Reserved Notation "c1 '/' st '||' s '/' st'"
                  (at level 40, st, s at level 39).

(** Intuitively, [c / st || s / st'] means that, if [c] is started in
    state [st], then it terminates in state [st'] and either signals
    that any surrounding loop (or the whole program) should exit
    immediately ([s = SBreak]) or that execution should continue
    normally ([s = SContinue]).

    The definition of the "[c / st || s / st']" relation is very
    similar to the one we gave above for the regular evaluation
    relation ([c / st || s / st']) -- we just need to handle the
    termination signals appropriately:

    - If the command is [SKIP], then the state doesn't change, and
      execution of any enclosing loop can continue normally.

    - If the command is [BREAK], the state stays unchanged, but we
      signal a [SBreak].

    - If the command is an assignment, then we update the binding for
      that variable in the state accordingly and signal that execution
      can continue normally.

    - If the command is of the form [IF b THEN c1 ELSE c2 FI], then
      the state is updated as in the original semantics of Imp, except
      that we also propagate the signal from the execution of
      whichever branch was taken.

    - If the command is a sequence [c1 ; c2], we first execute
      [c1]. If this yields a [SBreak], we skip the execution of [c2]
      and propagate the [SBreak] signal to the surrounding context;
      the resulting state should be the same as the one obtained by
      executing [c1] alone. Otherwise, we execute [c2] on the state
      obtained after executing [c1], and propagate the signal that was
      generated there.

    - Finally, for a loop of the form [WHILE b DO c END], the
      semantics is almost the same as before. The only difference is
      that, when [b] evaluates to true, we execute [c] and check the
      signal that it raises. If that signal is [SContinue], then the
      execution proceeds as in the original semantics. Otherwise, we
      stop the execution of the loop, and the resulting state is the
      same as the one resulting from the execution of the current
      iteration. In either case, since [BREAK] only terminates the
      innermost loop, [WHILE] signals [SContinue]. *)

(** Based on the above description, complete the definition of the
    [ceval] relation. *)

Inductive ceval : com -> state -> status -> state -> Prop :=
  | E_Skip : forall st,
      CSkip / st || SContinue / st
  | E_Break : forall st,
      CBreak / st || SBreak / st
  | E_CAss : forall (X:id)(a:aexp) st,
      CAss X a / st || SContinue / (update st X (aeval st a))
  | E_Seq_continue : forall st st' st'' c1 c2 s,
         c1 / st || SContinue / st' -> c2 / st' || s / st''
         -> (CSeq c1 c2) / st || s /st''
  | E_Seq_break : forall st c1 c2,
         c1 / st || SBreak / st -> (CSeq c1 c2) / st || SBreak / st
  | E_CIf_true : forall b c1 c2 s st st',
         beval st b = true ->
         c1 / st || s / st' -> (CIf b c1 c2) / st || s / st'
  | E_CIf_false : forall b c1 c2 s st st',
         beval st b = false ->
         c2 / st || s / st' -> (CIf b c1 c2) / st || s / st'
  | E_WhileEnd : forall b c st,
         beval st b = false ->
         (CWhile b c) / st || SContinue / st
  | E_WhileLoopB : forall b c st st',
         beval st b = true ->
         c / st || SBreak / st' ->
         (CWhile b c) / st || SContinue /st'  
  | E_WhileLoopC : forall b c st st' st'' s,
         beval st b = true ->
         c/ st || SContinue / st' ->
         (CWhile b c) / st' || s / st''->
         (CWhile b c) / st  || s / st''       
          
  (* FILL IN HERE *)

  where "c1 '/' st '||' s '/' st'" := (ceval c1 st s st').

Tactic Notation "ceval_cases" tactic(first) ident(c) :=
  first;
  [ Case_aux c "E_Skip"|Case_aux c "E_Break"|Case_aux c "E_CAss"
   |Case_aux c "E_Seq_continue"|Case_aux c "E_Seq_break"|Case_aux c "E_CIf_true"
   |Case_aux c "E_CIf_false"|Case_aux c "E_WhileEnd"|Case_aux c "E_WhileLoopS"
   |Case_aux c "E_WhileLoopC"
  (* FILL IN HERE *)
  ].

(** Now the following properties of your definition of [ceval]: *)

Theorem break_ignore : forall c st st' s,
     (BREAK; c) / st || s / st' ->
     st = st'.
Proof.
  intros.
  remember (BREAK;c) as e eqn:HSeq.
  induction H; inversion HSeq. 
  rewrite->H2 in H. inversion H. reflexivity.
Qed. 
  (* FILL IN HERE *) 

Theorem while_continue : forall b c st st' s,
  (WHILE b DO c END) / st || s / st' ->
  s = SContinue.
Proof.
  intros.
  remember (WHILE b DO c END) as e eqn:HSLoop.
  induction H;inversion HSLoop. reflexivity. 
  reflexivity. apply IHceval2. apply HSLoop. 
Qed. 
  (* FILL IN HERE *) 

Theorem while_stops_on_break : forall b c st st',
  beval st b = true ->
  c / st || SBreak / st' ->
  (WHILE b DO c END) / st || SContinue / st'.
Proof.
  intros.
  apply E_WhileLoopB. apply H. apply H0.
Qed.
  (* FILL IN HERE *)

Theorem while_break_true : forall b c st st',
  (WHILE b DO c END) / st || SContinue / st' ->
  beval st' b = true ->
  exists st'', c / st'' || SBreak / st'.
Proof.
  intros.
  remember (WHILE b DO c END) as e eqn:HSLoop. induction H;inversion HSLoop.
  rewrite->H2 in H. rewrite H in H0. inversion H0.
  exists st. rewrite<-H4. apply H1.
  apply IHceval2. apply HSLoop. apply H0.
Qed.

(* FILL IN HERE *)
Theorem ceval_deterministic: forall (c:com) st st1 st2 s1 s2,
     c / st || s1 / st1  ->
     c / st || s2 / st2 ->
     st1 = st2 /\ s1 = s2.
Proof.
  intros.
  generalize dependent st2 .
  generalize dependent s2 .
  induction H.
  Case "E_Skip". intros. inversion H0. auto. 
  Case "E_Break". intros. inversion H0. auto.
  Case "E_CAss". intros. inversion H0. auto.
  Case "E_Seq_continue". intros. inversion H1.
    SCase "c1->SContinue". assert (st' = st'0) as EQ1. subst. apply IHceval1 with SContinue. 
      apply H4. subst. apply IHceval2. apply H8. 
    SCase "c1->SBreak ". assert (SContinue=SBreak) as contra. eapply IHceval1. subst.
                        apply H7. inversion contra.
  Case "E_Seq_break". intros. inversion H0.
    SCase "c1->SContinue". assert (SBreak=SContinue) as contra.
                          eapply IHceval. apply H3. inversion contra.
    SCase "c1->SBreak". auto.
  Case "E_CIf_true". intros. inversion H1.
    SCase " beval st b = true". subst. apply IHceval. apply H9.
    SCase "beval st b = false". subst. rewrite->H in H8. inversion H8.
  Case "E_CIf_false". intros. inversion H1.
    SCase "beval st b = true". subst. rewrite->H in H8. inversion H8.
    SCase "beval st b = false". apply IHceval. apply H9.
  Case "E_WhileEnd". intros. inversion H0.
    SCase " beval st b = false". auto. rewrite->H in H3. inversion H3.
    SCase "beval st b = true".  rewrite->H in H3. inversion H3.
  Case "E_WhileLoopB". intros. inversion H1.
    SCase "beval st b = false". subst. rewrite->H in H7. inversion H7.
    SCase "beval st b = true& c->SBreak". split. eapply IHceval. apply H8. reflexivity.
    SCase "beval st b = true& c->SContinue". assert (SBreak=SContinue) as contra.
                      eapply IHceval. apply H5. inversion contra.
  Case "E_WhileLoopC". intros. inversion H2.
    SCase "beval st b = false". subst. rewrite->H in H8. inversion H8.
    SCase "beval st b = true&c->SBreak". assert (SContinue=SBreak) as contra.
                      eapply IHceval1. apply H9. inversion contra.
    SCase "beval st b = true&c->SContinue". subst. assert (st' = st'0) as EQ1.
                      eapply IHceval1. apply H6. apply IHceval2. subst. apply H10.
Qed.
           
End BreakImp.
(** [] *)

(** **** Exercise: 3 stars, optional (short_circuit) *)
(** Most modern programming languages use a "short-circuit" evaluation
    rule for boolean [and]: to evaluate [BAnd b1 b2], first evaluate
    [b1].  If it evaluates to [false], then the entire [BAnd]
    expression evaluates to [false] immediately, without evaluating
    [b2].  Otherwise, [b2] is evaluated to determine the result of the
    [BAnd] expression.

    Write an alternate version of [beval] that performs short-circuit
    evaluation of [BAnd] in this manner, and prove that it is
    equivalent to [beval]. *)
Fixpoint alter_beval (st : state) (b : bexp) : bool :=
  match b with
  | BTrue       => true
  | BFalse      => false
  | BEq a1 a2   => beq_nat (aeval st a1) (aeval st a2)
  | BLe a1 a2   => ble_nat (aeval st a1) (aeval st a2)
  | BNot b1     => negb (beval st b1)
  | BAnd b1 b2  => match (beval st b1) with 
                    |true=> beval st b2
                    |false => false
                   end
  end.
Theorem alter_beval__beval :
   forall st b , alter_beval st b = beval st b.
Proof.
  intros. induction b;simpl;try reflexivity.
Qed. 
(* FILL IN HERE *)
(** [] *)

(** **** Exercise: 4 stars, optional (add_for_loop) *)
(** Add C-style [for] loops to the language of commands, update the
    [ceval] definition to define the semantics of [for] loops, and add
    cases for [for] loops as needed so that all the proofs in this file
    are accepted by Coq.

    A [for] loop should be parameterized by (a) a statement executed
    initially, (b) a test that is run on each iteration of the loop to
    determine whether the loop should continue, (c) a statement
    executed at the end of each loop iteration, and (d) a statement
    that makes up the body of the loop.  (You don't need to worry
    about making up a concrete Notation for [for] loops, but feel free
    to play with this too if you like.) *)
Module ForImp.
Inductive com : Type :=
  | CSkip : com
  | CBreak : com
  | CAss : id -> aexp -> com
  | CSeq : com -> com -> com
  | CIf : bexp -> com -> com -> com
  | CWhile : bexp -> com -> com
  | CFor : com -> bexp -> com -> com -> com.

 Tactic Notation "com_cases" tactic(first) ident(c):=
  first;
  [ Case_aux c "SKIP" | Case_aux c "BREAK" | Case_aux c "::=" | Case_aux c ";"
  | Case_aux c "IFB" | Case_aux c "WHILE" |Case_aux c "FOR" ].

Notation "'SKIP'" :=
  CSkip.
Notation "'BREAK'" :=
  CBreak.
Notation "x '::=' a" :=
  (CAss x a) (at level 60).
Notation "c1 ; c2" :=
  (CSeq c1 c2) (at level 80, right associativity).
Notation "'WHILE' b 'DO' c 'END'" :=
  (CWhile b c) (at level 80, right associativity).
Notation "'IFB' c1 'THEN' c2 'ELSE' c3 'FI'" :=
  (CIf c1 c2 c3) (at level 80, right associativity).
Notation "'For' c1 b c2 'DO' c3 'ENDFOR'":=
  (CFor c1 b c2 c3)(at level 80, right associativity).

Inductive status : Type :=
  | SContinue : status
  | SBreak : status.

Reserved Notation "c1 '/' st '||' s '/' st'"
                  (at level 40, st, s at level 39).

Inductive ceval : com -> state -> status -> state -> Prop :=
  | E_Skip : forall st,
      CSkip / st || SContinue / st
  | E_Break : forall st,
      CBreak / st || SBreak / st
  | E_CAss : forall (X:id)(a:aexp) st,
      CAss X a / st || SContinue / (update st X (aeval st a))
  | E_Seq_continue : forall st st' st'' c1 c2 s,
         c1 / st || SContinue / st' -> c2 / st' || s / st''
         -> (CSeq c1 c2) / st || s /st''
  | E_Seq_break : forall st c1 c2,
         c1 / st || SBreak / st -> (CSeq c1 c2) / st || SBreak / st
  | E_CIf_true : forall b c1 c2 s st st',
         beval st b = true ->
         c1 / st || s / st' -> (CIf b c1 c2) / st || s / st'
  | E_CIf_false : forall b c1 c2 s st st',
         beval st b = false ->
         c2 / st || s / st' -> (CIf b c1 c2) / st || s / st'
  | E_WhileEnd : forall b c st,
         beval st b = false ->
         (CWhile b c) / st || SContinue / st
  | E_WhileLoopB : forall b c st st',
         beval st b = true ->
         c / st || SBreak / st' ->
         (CWhile b c) / st || SContinue /st'  
  | E_WhileLoopC : forall b c st st' st'' s,
         beval st b = true ->
         c/ st || SContinue / st' ->
         (CWhile b c) / st' || s / st''->
         (CWhile b c) / st  || s / st''    
  | E_ForLoop :  forall c1 c2 c3 b s st st',
         c1 / st || s / st' ->
         beval st' b = false->
         (CFor c1 b c2 c3) / st || SContinue / st'
  | E_ForLoopB : forall c1 c2 c3 b s st st' st'',
         c1 / st || s / st' ->
         beval st' b = true ->
         c3 / st' || SBreak / st''->
         (CFor c1 b c2 c3 ) / st || SContinue / st''
  | E_ForLoopC : forall s s' s'' c1 c2 c3 st st' st'' st''' st'''' b,
         c1 / st || s / st' ->
         beval st' b = true ->
         c3 / st' || SContinue / st''->
         c2 / st'' || s' / st''' ->
         (CFor c1 b c2 c3) / st''' || s'' / st''''->
         (CFor c1 b c2 c3) / st || s'' / st''''

  where "c1 '/' st '||' s '/' st'" := (ceval c1 st s st').

Tactic Notation "ceval_cases" tactic(first) ident(c) :=
  first;
  [ Case_aux c "E_Skip"|Case_aux c "E_Break"|Case_aux c "E_CAss"
   |Case_aux c "E_Seq_continue"|Case_aux c "E_Seq_break"|Case_aux c "E_CIf_true"
   |Case_aux c "E_CIf_false"|Case_aux c "E_WhileEnd"|Case_aux c "E_WhileLoopS"
   |Case_aux c "E_WhileLoopC"|Case_aux c "ForLoop"|Case_aux c "E_ForLoopB"
   |Case_aux c "E_ForLoopC"
  ].
Theorem break_ignore : forall c st st' s,
     (BREAK; c) / st || s / st' ->
     st = st'.
Proof.
  intros.
  remember (BREAK;c) as e eqn:HSeq.
  induction H; inversion HSeq. 
  rewrite->H2 in H. inversion H. reflexivity.
Qed. 

Theorem while_continue : forall b c st st' s,
  (WHILE b DO c END) / st || s / st' ->
  s = SContinue.
Proof.
  intros.
  remember (WHILE b DO c END) as e eqn:HSLoop.
  induction H;inversion HSLoop. reflexivity. 
  reflexivity. apply IHceval2. apply HSLoop. 
Qed. 

Theorem while_stops_on_break : forall b c st st',
  beval st b = true ->
  c / st || SBreak / st' ->
  (WHILE b DO c END) / st || SContinue / st'.
Proof.
  intros.
  apply E_WhileLoopB. apply H. apply H0.
Qed.
 
Theorem while_break_true : forall b c st st',
  (WHILE b DO c END) / st || SContinue / st' ->
  beval st' b = true ->
  exists st'', c / st'' || SBreak / st'.
Proof.
  intros.
  remember (WHILE b DO c END) as e eqn:HSLoop. induction H;inversion HSLoop.
  rewrite->H2 in H. rewrite H in H0. inversion H0.
  exists st. rewrite<-H4. apply H1.
  apply IHceval2. apply HSLoop. apply H0.
Qed.
Theorem ceval_deterministic: forall (c:com) st st1 st2 s1 s2,
     c / st || s1 / st1  ->
     c / st || s2 / st2 ->
     st1 = st2 /\ s1 = s2.
Proof.
    intros.
  generalize dependent st2 .
  generalize dependent s2 .
  induction H.
  Case "E_Skip". intros. inversion H0. auto. 
  Case "E_Break". intros. inversion H0. auto.
  Case "E_CAss". intros. inversion H0. auto.
  Case "E_Seq_continue". intros. inversion H1.
    SCase "c1->SContinue". assert (st' = st'0) as EQ1. subst. apply IHceval1 with SContinue. 
      apply H4. subst. apply IHceval2. apply H8. 
    SCase "c1->SBreak ". assert (SContinue=SBreak) as contra. eapply IHceval1. subst.
                        apply H7. inversion contra.
  Case "E_Seq_break". intros. inversion H0.
    SCase "c1->SContinue". assert (SBreak=SContinue) as contra.
                          eapply IHceval. apply H3. inversion contra.
    SCase "c1->SBreak". auto.
  Case "E_CIf_true". intros. inversion H1.
    SCase " beval st b = true". subst. apply IHceval. apply H9.
    SCase "beval st b = false". subst. rewrite->H in H8. inversion H8.
  Case "E_CIf_false". intros. inversion H1.
    SCase "beval st b = true". subst. rewrite->H in H8. inversion H8.
    SCase "beval st b = false". apply IHceval. apply H9.
  Case "E_WhileEnd". intros. inversion H0.
    SCase " beval st b = false". auto. rewrite->H in H3. inversion H3.
    SCase "beval st b = true".  rewrite->H in H3. inversion H3.
  Case "E_WhileLoopB". intros. inversion H1.
    SCase "beval st b = false". subst. rewrite->H in H7. inversion H7.
    SCase "beval st b = true& c->SBreak". split. eapply IHceval. apply H8. reflexivity.
    SCase "beval st b = true& c->SContinue". assert (SBreak=SContinue) as contra.
                      eapply IHceval. apply H5. inversion contra.
  Case "E_WhileLoopC". intros. inversion H2.
    SCase "beval st b = false". subst. rewrite->H in H8. inversion H8.
    SCase "beval st b = true&c->SBreak". assert (SContinue=SBreak) as contra.
                      eapply IHceval1. apply H9. inversion contra.
    SCase "beval st b = true&c->SContinue". subst. assert (st' = st'0) as EQ1.
                      eapply IHceval1. apply H6. apply IHceval2. subst. apply H10.
  Case "E_ForLoop". intros. inversion H1.
    SCase "beval st' b = false". subst. split. eapply IHceval. apply H9. reflexivity.
    SCase "beval st' b = true & c3-> SBreak ". subst. assert(st' = st'0) as EQ1. eapply IHceval. 
                       apply H9. rewrite->EQ1 in H0. rewrite->H0 in H10. inversion H10.
    SCase "beval st' b = true & c3-> SContinue". subst. assert(st' = st'0) as EQ1. eapply IHceval.
                       apply H6. rewrite->EQ1 in H0. rewrite->H0 in H7. inversion H7.
  Case "E_ForLoopB". intros. inversion H2. 
    SCase  "beval st b = false". subst. assert(st' = st2) as EQ1. eapply IHceval1. apply H10.
                       rewrite->EQ1 in H0. rewrite->H0 in H11. inversion H11.
    SCase "beval st b = true &SBreak". subst. assert(st' = st'0) as EQ1. eapply IHceval1. apply H10.
                       split. eapply IHceval2. rewrite->EQ1. apply H12. reflexivity.
    SCase "beval st b = true &SContinue". subst. assert (SBreak=SContinue) as contra. 
                       eapply IHceval2. assert(st' = st'0) as EQ1. eapply IHceval1. apply H7.
                       rewrite->EQ1. apply H12. inversion contra.
  Case "E_ForLoopC". intros. inversion H4.
    SCase "false". subst. assert(st' = st2) as EQ1. eapply IHceval1. apply H12. rewrite->EQ1 in H0.
                       rewrite->H0 in H13. inversion H13.
    SCase "true & SBreak ". subst. assert (SContinue=SBreak) as contra. eapply IHceval2.
                       assert(st' = st'0) as EQ1. eapply IHceval1. apply H12. 
                       rewrite->EQ1. apply H14. inversion contra.
    SCase "true & SContinue". subst. assert(st''' = st'''0) as EQ1. eapply IHceval3. 
                                    assert(st'' = st''0) as EQ2. eapply IHceval2.
                                    assert(st' = st'0) as EQ1. eapply IHceval1.
                       apply H9. rewrite->EQ1. apply H14. rewrite->EQ2. apply H15.
                       apply IHceval4. rewrite->EQ1. apply H16.
Qed.

(* FILL IN HERE *)
(** [] *)
End ForImp.

(* <$Date: 2013-07-17 16:19:11 -0400 (Wed, 17 Jul 2013) $ *)

