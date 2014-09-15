#ifdef DEBUG
prettyprint(label, x) {
  decl sep = "\n--------------------------\n";
  print(label,sep,x,sep,"\n\n");
}
#else
prettyprint(label, x) {}
#endif

decl i = 1;

DetergentData::DetergentData(method) {
	DataSet("Detergent", method, TRUE);
	Observed(Detergent::weeks_to_go,"wks_to_g",
					 Detergent::purchase,"purch",
					 Detergent::coupon_ch,"cpn_ch",
					 Detergent::coupon_other, "cpn_oth",
					 Detergent::coupon_td, "cpn_td",
					 Detergent::consumption, "cons");
	IDColumn("hh_id");
	Read("sample.dta");
}

DetergentEstimates::DoAll() {
	Detergent::FirstStage();
	EMax = new ValueIteration(0);
	EMax.vtoler  = 1E-1;

  detergent = new DetergentData(EMax);

	nfxp = new PanelBB("DetergentMLE1", detergent,Detergent::hat);
	nfxp.Volume = LOUD;
	mle = new NelderMead(nfxp);
	mle.Volume = LOUD;

	Outcome::OnlyTransitions = TRUE;
	EMax.DoNotIterate = TRUE;
	mle -> Iterate(0);

	Detergent::SecondStage();
	Outcome::OnlyTransitions = FALSE;
	EMax.DoNotIterate = FALSE;
	nfxp -> ResetMax();
	mle -> Iterate(0);

	delete mle, nfxp, EMax;
	Bellman::Delete();
}

Detergent::FirstStage() {
	hat = new array[N_PARAMS];
	Initialize(1.0,Reachable,FALSE,0);

	hat[DISCOUNT] = new Determined("delta",init_hat[DISCOUNT]);
	hat[STOCKOUT_COSTS] = new Coefficients("alpha", init_hat[STOCKOUT_COSTS]);
	hat[INVENTORY_HOLDING_COSTS] = new Coefficients("eta", init_hat[INVENTORY_HOLDING_COSTS]);
	hat[PERCIEVED_COUPON_VALUES] = new Coefficients("gamma", init_hat[PERCIEVED_COUPON_VALUES]);

	SetDelta(hat[DISCOUNT]);

	purchase = new ActionVariable("purchase", 7);
  purchase.actual = <0;17;42;72;127;227;400.0>;
  Actions(purchase);
	prettyprint("Purchases", purchase);

  consumption = new FixedEffect("consumption", 11);
  consumption.actual = (consumption.vals + 1)*5;
  prettyprint("Consumption", consumption);

  weeks_to_go = new InventoryState("weeks_to_go", NX, consumption, purchase);
  prettyprint("Weeks Left", weeks_to_go);

  coupon_ch = new Jump("coupon_ch", 2, CV(hat[PERCIEVED_COUPON_VALUES])[0]);
  prettyprint("Coupon (Cheer)", coupon_ch);

  coupon_other = new Jump("coupon_other", 2, CV(hat[PERCIEVED_COUPON_VALUES])[1]);
  prettyprint("Coupon (Other)", coupon_other);

  coupon_td = new Jump("coupon_td", 2, CV(hat[PERCIEVED_COUPON_VALUES])[2]);
  prettyprint("Coupon (Tide)", coupon_td);
  
  EndogenousStates(weeks_to_go);
  ExogenousStates(coupon_ch, coupon_other, coupon_td);
  GroupVariables(consumption);
	CreateSpaces();
	hat[STOCKOUT_COSTS]->ToggleDoNotVary();
	hat[INVENTORY_HOLDING_COSTS]->ToggleDoNotVary();	
}

Detergent::SecondStage() {
	hat[STOCKOUT_COSTS]->ToggleDoNotVary();
	hat[INVENTORY_HOLDING_COSTS]->ToggleDoNotVary();
	hat[PERCIEVED_COUPON_VALUES]->ToggleDoNotVary();
}

Detergent::Reachable() { return new Detergent(); }
Detergent::Utility() {
	decl buy = aa(purchase);
	return -(
		CV(hat[ALPHA])[0] + CV(hat[alpha])[1]*AV(consumption)*(buy==0) /* stockout cost */ + 
		CV(hat[ETA])[0]*AV(weeks_to_go) + CV(hat[ETA])[1]*AV(weeks_to_go)^2 /* inventory holding costs */ -
		(CV(hat[GAMMA])[0]*AV(coupon_ch) + CV(hat[GAMMA])[1]*AV(coupon_other) +CV(hat[GAMMA])[2]*AV(coupon_td)) * (buy!=0)); // coupon preference weights
}

/*
		CV(hat[ALPHA]) * <1.0; consumption> * (buy==0) + // stockout cost 
		CV(hat[ETA])* <weeks_to_go; weeks_to_go^2> - // inventory holding costs
		CV(hat[GAMMA])* <cpn_ch; cpn_oth; cpn_td> * (buy!=0)); // coupon preference weights
*/
