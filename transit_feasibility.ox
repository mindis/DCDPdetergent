#import "Inventory"
#import <database>
#import "DDP"

feasible_hh(timep, wtg, purch, cons) {
  decl i, n = sizerc(wtg);

  decl consumption = new ConsumptionState("cons", 11);
  consumption.actual = (consumption.vals + 1)*5;
  //print("Actual: ", consumption);

  decl purchase = new ActionVariable("purch", 7);
  purchase.actual = <0;17;42;72;127;227;400.0>;
  purchase.pos = 0;

  decl inventory = new InventoryState("inv", 115, consumption, purchase);
  decl FeasA = purchase.vals';

  decl expected_transition, actual_transition;
  decl exp_feas_states, exp_trans_prob;  

  for (i = 0; i < n-1; i++) {
    // update the State/Action variables to have the right values
    consumption.v = cons[i]; //consumption.actual[cons[i]];
    purchase.v = purch[i]; //purchase.actual[purch[i]];
    inventory.v = wtg[i]; //inventory.actual[wtg[i]];

    // expected feasible transition given consumption/purchase
    [exp_feas_states, exp_trans_prob] = inventory.Transit(FeasA); 
    expected_transition = max(exp_feas_states .* exp_trans_prob[purch[i]][]);
    /*
    print("purch: ", purchase.v);
    print("\t\twtg: ", AV(inventory));
    print("\t\tcons: ", AV(consumption), "\t", consumption.actual[consumption.v], "\t", cons[i]);

    print("\nefs: ", exp_feas_states,
        "etp: ", exp_trans_prob[purch[i]][]);
    decl x = exp_feas_states .* exp_trans_prob[purch[i]][];
    print("x: ", x);
*/
    // actual feasible transition
    actual_transition = wtg[i+1];
    
    if (actual_transition != expected_transition) {
    print("Time: ", timep[i+1],
        "\tConsump: ", AV(consumption), "\t", consumption.v, "\t", consumption.actual[consumption.v], 
        "\tPurchase: ", purch[i],
        "\tInventory: ", AV(inventory),
        "\tExpected: ", expected_transition,
        "\tActual: ", actual_transition, "\n");
    }

  }
}

feasible_hhs(db) {
  db.Info();

  decl hhs = db.GetVar("hh_id");
  decl time_data = db.GetVar("week");
  decl wtg_data =   db.GetVar("wks_to_g");
  decl purch_data = db.GetVar("purch");
  decl cons_data =  db.GetVar("cons");

  decl unique_hhs = unique(hhs);
  decl i, hh_idx, timep, wtg, purch, cons;

  // check feasibility for each household
  for (i = 0; i < sizerc(unique_hhs); i++) {
    hh_idx = hhs .== unique_hhs[i];

    timep = selectifr(time_data, hh_idx);
    wtg = selectifr(wtg_data, hh_idx);
    purch = selectifr(purch_data, hh_idx);
    cons = selectifr(cons_data, hh_idx);
   
    print("\n\n\nHousehold: ");
    print("%10d", unique_hhs[i]);
    print("\n--------------------------------\n");
    feasible_hh(timep, wtg, purch, cons);
  }
}

main() {
  // load in the data 
  decl db = new Database();
  db.Load("sample.dta");

  feasible_hhs(db);
}
