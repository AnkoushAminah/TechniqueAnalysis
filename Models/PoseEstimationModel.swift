//
//  PoseEstimationModel.swift
//  TechniqueAnalysis
//
//  Created by Trevor Phillips on 12/11/18.
//

import Vision
import CoreMedia

public protocol PoseEstimationDelegate: class {
    func visionRequestDidComplete(heatmap: MLMultiArray)
    func visionRequestDidFail(error: Error?)
    func didSamplePerformance(inferenceTime: Double, executionTime: Double, fps: Int)
}

public class PoseEstimationModel {

    // MARK: - Core ML Model

    private typealias CPMEstimationModel = cpm_model
    private typealias HourglassEstimationModel = hourglass_model

    public enum ModelType {
        case cpm, hourglass
    }

    // MARK: - Properties

    public weak var delegate: PoseEstimationDelegate?
    private var videoCapture: VideoCapture
    private let performanceTool = PerformanceTool()
    private var request: VNCoreMLRequest?

    public var videoPreviewLayer: CALayer? {
        return videoCapture.previewLayer
    }

    // MARK: - Initialization

    public init?(type: ModelType) {
        self.videoCapture = VideoCapture(fps: 30)

        let success: Bool
        switch type {
        case .cpm:
            success = configureCPMModel()
        case .hourglass:
            success = configureHourglassModel()
        }

        if !success {
            return nil
        }

        self.performanceTool.delegate = self
        self.videoCapture.delegate = self
    }

    // MARK: - Public Functions

    public func setupCameraPreview(withinView view: UIView) {
        videoCapture.setup(sessionPreset: .vga640x480) { [weak self] success in
            guard success else {
                return
            }

            if let previewLayer = self?.videoCapture.previewLayer {
                view.layer.addSublayer(previewLayer)
                self?.videoCapture.previewLayer?.frame = view.bounds
            }

            self?.videoCapture.start()
        }
    }

    public func tearDownCameraPreview() {
        videoCapture.stop()
        videoCapture.previewLayer?.removeFromSuperlayer()
    }

    // MARK: - Private Functions

    private func visionRequestDidComplete(request: VNRequest, error: Error?) {
        performanceTool.endInference()
        if let observations = request.results as? [VNCoreMLFeatureValueObservation],
            let heatmap = observations.first?.featureValue.multiArrayValue {
            performanceTool.stop()
            DispatchQueue.main.async {
                self.delegate?.visionRequestDidComplete(heatmap: heatmap)
            }
        } else {
            delegate?.visionRequestDidFail(error: error)
            performanceTool.stop()
        }
    }

    private func predictUsingVision(pixelBuffer: CVPixelBuffer) {
        guard let request = request else {
            return
        }

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer)
        try? handler.perform([request])
    }

    private func configureCPMModel() -> Bool {
        do {
            let mlModel: MLModel
            if #available(iOS 12.0, *) {
                let config = MLModelConfiguration()
                config.computeUnits = .all
                mlModel = try CPMEstimationModel(contentsOf: CPMEstimationModel.urlOfModelInThisBundle,
                                                 configuration: config).model
            } else {
                mlModel = try CPMEstimationModel(contentsOf: CPMEstimationModel.urlOfModelInThisBundle).model
            }
            let visionModel = try VNCoreMLModel(for: mlModel)
            configureRequest(with: visionModel)
            return true
        } catch {
            print("ERROR: - Unable to create CoreML model, \(error.localizedDescription)")
            return false
        }
    }

    private func configureHourglassModel() -> Bool {
        do {
            let url = HourglassEstimationModel.urlOfModelInThisBundle
            let mlModel: MLModel
            if #available(iOS 12.0, *) {
                let config = MLModelConfiguration()
                config.computeUnits = .all
                mlModel = try HourglassEstimationModel(contentsOf: url, configuration: config).model
            } else {
                mlModel = try HourglassEstimationModel(contentsOf: url).model
            }
            let visionModel = try VNCoreMLModel(for: mlModel)
            configureRequest(with: visionModel)
            return true
        } catch {
            print("ERROR: - Unable to create CoreML model, \(error.localizedDescription)")
            return false
        }
    }

    private func configureRequest(with visionModel: VNCoreMLModel) {
        let request = VNCoreMLRequest(model: visionModel, completionHandler: visionRequestDidComplete)
        request.imageCropAndScaleOption = .scaleFill
        self.request = request
    }

}

extension PoseEstimationModel: VideoCaptureDelegate {

    func videoCapture(_ capture: VideoCapture,
                      didCaptureFrame frame: CVPixelBuffer?,
                      timestamp: CMTime) {
        if let pixelBuffer = frame {
            performanceTool.start()
            predictUsingVision(pixelBuffer: pixelBuffer)
        }
    }

}

extension PoseEstimationModel: PerformanceToolDelegate {

    func updateSample(inferenceTime: Double, executionTime: Double, fps: Int) {
        DispatchQueue.main.async {
            self.delegate?.didSamplePerformance(inferenceTime: inferenceTime,
                                                executionTime: executionTime,
                                                fps: fps)
        }
    }

}