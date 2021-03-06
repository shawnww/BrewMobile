//
//  ViewController.swift
//  BrewMobile
//
//  Created by Ágnes Vásárhelyi on 19/08/14.
//  Copyright (c) 2014 Ágnes Vásárhelyi. All rights reserved.
//

import UIKit
import SwiftyJSON
import ReactiveCocoa

class BrewViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    let brewViewModel: BrewViewModel
    
    @IBOutlet weak var tempLabel: UILabel!
    @IBOutlet weak var pwmLabel: UILabel!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var startTimeLabel: UILabel!
    @IBOutlet weak var phasesTableView: UITableView!
    @IBOutlet weak var stopButton: UIButton!
    
    init(brewViewModel: BrewViewModel) {
        self.brewViewModel = brewViewModel
        super.init(nibName:"BrewViewController", bundle: nil)
        self.tabBarItem = UITabBarItem(title: "Brew", image: UIImage(named: "HopIcon"), tag: 0)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        stopButton.addTarget(self.brewViewModel.cocoaActionStop, action: CocoaAction.selector, forControlEvents: .TouchUpInside)

        let nib = UINib(nibName: "BrewCell", bundle: nil)
        phasesTableView.registerNib(nib, forCellReuseIdentifier: "BrewCell")

        self.tempLabel.rac_text <~ self.brewViewModel.temp.producer
            .map { temp in
                return String(format:"%.2f ˚C", temp)
            }
            .flatMapError { _ in SignalProducer<String, NoError>.empty }
        
        self.pwmLabel.rac_text <~ self.brewViewModel.pwm.producer
            .map { pwm in
                return String(format:"PWM %g %%", pwm)
            }
            .flatMapError { _ in SignalProducer<String, NoError>.empty }
        
        self.brewViewModel.brew.producer
            .on (next: { brewState in
                self.phasesTableView.reloadData()
                
                if brewState.phases.value.count > 0 {
                    self.nameLabel.text = "Brewing \(brewState.name.value) at"
                } else {
                    self.nameLabel.text = "We are not brewing :(\nHow is it possible?"
                }
                
                self.startTimeLabel.text = brewState.phases.value.count > 0 ? "starting \(brewState.startTime.value)" : ""
            })
            .start()
    }
    
    func stateText(brewPhase: BrewPhase) -> String {
        if self.brewViewModel.brew.value.paused.value {
            return "paused"
        }
        switch brewPhase.state  {
        case State.FINISHED:
            return "\(brewPhase.state.stateDescription()) at \(brewPhase.jobEnd)"
        case State.HEATING:
            if self.brewViewModel.temp.value > brewPhase.temp { return "cooling" }
            fallthrough
        default:
            return brewPhase.state.stateDescription()
        }
    }
    
    // MARK: UITableViewDataSource
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.brewViewModel.brew.value.phases.value.count
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("BrewCell", forIndexPath: indexPath) as! BrewCell
        if self.brewViewModel.brew.value.phases.value.count > indexPath.row  {
            let brewPhase = self.brewViewModel.brew.value.phases.value[indexPath.row]
            
            let showEnd: Bool = brewPhase.tempReached && brewPhase.inProgress
            cell.minLabel.text = showEnd ? "\(brewPhase.min) mins - \(Int(brewPhase.temp)) ˚C, ends: \(brewPhase.jobEnd)" : "\(brewPhase.min) mins - \(Int(brewPhase.temp)) ˚C"
            cell.statusLabel.text = "\(self.stateText(brewPhase))"
            
            UIView.animateWithDuration(0.3, animations: { () -> Void in
                cell.backgroundColor = brewPhase.state.bgColor()
                cell.setTextColorForAllLabels(brewPhase.state == State.INACTIVE ? UIColor.blackColor() : UIColor.whiteColor())
            })
        }
        
        return cell
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
}
