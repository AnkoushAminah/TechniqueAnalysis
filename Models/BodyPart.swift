//
//  BodyPart.swift
//  TechniqueAnalysis
//
//  Created by Trevor on 04.12.18.
//

import UIKit

public enum BodyPart: Int, CaseIterable {

    case top
    case neck
    case rightShoulder
    case rightElbow
    case rightWrist
    case leftShoulder
    case leftElbow
    case leftWrist
    case rightHip
    case rightKnee
    case rightAnkle
    case leftHip
    case leftKnee
    case leftAnkle

    public static var joints: [(BodyPart, BodyPart)] {
        return [
            (.top, .neck),
            (.neck, .rightShoulder),
            (.rightShoulder, .rightElbow),
            (.rightElbow, .rightWrist),
            (.neck, .rightHip),
            (.rightHip, .rightKnee),
            (.rightKnee, .rightAnkle),
            (.neck, .leftShoulder),
            (.leftShoulder, .leftElbow),
            (.leftElbow, .leftWrist),
            (.neck, .leftHip),
            (.leftHip, .leftKnee),
            (.leftKnee, .leftAnkle)
        ]
    }

}