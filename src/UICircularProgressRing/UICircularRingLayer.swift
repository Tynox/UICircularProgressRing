//
//  UICircularRingLayer.swift
//  UICircularProgressRing
//
//  Copyright (c) 2019 Luis Padron
//
//  Permission is hereby granted, free of charge, to any person obtaining a
//  copy of this software and associated documentation files (the "Software"),
//  to deal in the Software without restriction, including without limitation the
//  rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is furnished
//  to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included
// in all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
//  INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND
//  NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE
//  FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT
//  OR OTHERWISE, ARISING FROM, OUT OF OR IN
//  CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//

import UIKit

/**
 The internal subclass for CAShapeLayer.
 This is the class that handles all the drawing and animation.
 This class is not interacted with, instead
 properties are set in UICircularRing and those are delegated to here.
 
 */
class UICircularRingLayer: CAShapeLayer {

    // MARK: Properties

    @NSManaged var value: CGFloat
    @NSManaged var minValue: CGFloat
    @NSManaged var maxValue: CGFloat

    /// formatter for the text of the value label
    @NSManaged var valueFormatter: UICircularRingValueFormatter?

    /// the delegate for the value, is notified when value changes
    @NSManaged weak var ring: UICircularRing!

    /// the style for the value knob
    var valueKnobStyle: UICircularRingValueKnobStyle?

    // MARK: Animation members

    var animationDuration: TimeInterval = 1.0
    var animationTimingFunction: CAMediaTimingFunctionName = .easeInEaseOut
    var animated = false

    /// the value label which draws the text for the current value
    lazy var valueLabel: UILabel = UILabel(frame: .zero)

    // MARK: Animatable properties

    /// whether or not animatable properties should be animated when changed
    var shouldAnimateProperties: Bool = false

    /// the animation duration for a animatable property animation
    var propertyAnimationDuration: TimeInterval = 0.0

    /// the properties which are animatable
    static let animatableProperties: [String] = ["innerRingWidth", "innerRingColor",
                                                         "outerRingWidth", "outerRingColor",
                                                         "fontColor", "innerRingSpacing"]

    // Returns whether or not a given property key is animatable
    static func isAnimatableProperty(_ key: String) -> Bool {
        return animatableProperties.index(of: key) != nil
    }

    // MARK: Draw

    /**
     Overriden for custom drawing.
     Draws the outer ring, inner ring and value label.
     */
    override func draw(in ctx: CGContext) {
        super.draw(in: ctx)
        UIGraphicsPushContext(ctx)
        // Draw the rings
        drawOuterRing()
        drawInnerRing(in: ctx)
        // Draw the label
        drawValueLabel()
        // Call the delegate and notifiy of updated value
        if let updatedValue = value(forKey: "value") as? CGFloat {
            ring.didUpdateValue(newValue: updatedValue)
        }
        UIGraphicsPopContext()

    }

    // MARK: Animation methods

    /**
     Watches for changes in the value property, and setNeedsDisplay accordingly
     */
    override class func needsDisplay(forKey key: String) -> Bool {
        if key == "value" || isAnimatableProperty(key) {
            return true
        } else {
            return super.needsDisplay(forKey: key)
        }
    }

    /**
     Creates animation when value property is changed
     */
    override func action(forKey event: String) -> CAAction? {
        if event == "value" && animated {
            let animation = CABasicAnimation(keyPath: "value")
            animation.fromValue = presentation()?.value(forKey: "value")
            animation.timingFunction = CAMediaTimingFunction(name: animationTimingFunction)
            animation.duration = animationDuration
            return animation
        } else if UICircularRingLayer.isAnimatableProperty(event) && shouldAnimateProperties {
            let animation = CABasicAnimation(keyPath: event)
            animation.fromValue = presentation()?.value(forKey: event)
            animation.timingFunction = CAMediaTimingFunction(name: animationTimingFunction)
            animation.duration = propertyAnimationDuration
            return animation
        } else {
            return super.action(forKey: event)
        }
    }

    // MARK: Helpers

    /**
     Draws the outer ring for the view.
     Sets path properties according to how the user has decided to customize the view.
     */
    private func drawOuterRing() {
        guard ring.outerRingWidth > 0 else { return }
        let center: CGPoint = CGPoint(x: bounds.midX, y: bounds.midY)
        let offSet = max(ring.outerRingWidth, ring.innerRingWidth) / 2
                        + ((ring.valueKnobStyle?.size ??  0 ) / 4)
                        + (ring.outerBorderWidth * 2)
        let outerRadius: CGFloat = min(bounds.width, bounds.height) / 2 - offSet
        let start: CGFloat = ring.fullCircle ? 0 : ring.startAngle.toRads
        let end: CGFloat = ring.fullCircle ? .pi * 2 : ring.endAngle.toRads
        let outerPath = UIBezierPath(arcCenter: center,
                                     radius: outerRadius,
                                     startAngle: start,
                                     endAngle: end,
                                     clockwise: true)
        outerPath.lineWidth = ring.outerRingWidth
        outerPath.lineCapStyle = ring.outerCapStyle
        // Update path depending on style of the ring
        updateOuterRingPath(outerPath, radius: outerRadius, style: ring.ringStyle)

        ring.outerRingColor.setStroke()
        outerPath.stroke()
    }

    /**
     Draws the inner ring for the view.
     Sets path properties according to how the user has decided to customize the view.
     */
    private func drawInnerRing(in ctx: CGContext) {
        guard ring.innerRingWidth > 0 else { return }

        let center: CGPoint = CGPoint(x: bounds.midX, y: bounds.midY)

        let innerEndAngle = calculateInnerEndAngle()
        let radiusIn = calculateInnerRadius()

        // Start drawing
        let innerPath: UIBezierPath = UIBezierPath(arcCenter: center,
                                                   radius: radiusIn,
                                                   startAngle: ring.startAngle.toRads,
                                                   endAngle: innerEndAngle.toRads,
                                                   clockwise: ring.isClockwise)

        // Draw path
        ctx.setLineWidth(ring.innerRingWidth)
        ctx.setLineJoin(.round)
        ctx.setLineCap(ring.innerCapStyle)
        ctx.setStrokeColor(ring.innerRingColor.cgColor)
        ctx.addPath(innerPath.cgPath)
        ctx.drawPath(using: .stroke)

        if ring.ringStyle == .gradient && ring.gradientColors.count > 1 {
            // Create gradient and draw it
            var cgColors: [CGColor] = [CGColor]()
            for color: UIColor in ring.gradientColors {
                cgColors.append(color.cgColor)
            }

            guard let gradient: CGGradient = CGGradient(colorsSpace: nil,
                                                        colors: cgColors as CFArray,
                                                        locations: ring.gradientColorLocations)
            else {
                fatalError("\nUnable to create gradient for progress ring.\n" +
                    "Check values of gradientColors and gradientLocations.\n")
            }

            ctx.saveGState()
            ctx.addPath(innerPath.cgPath)
            ctx.replacePathWithStrokedPath()
            ctx.clip()

            drawGradient(gradient, start: ring.gradientStartPosition,
                         end: ring.gradientEndPosition, in: ctx)

            ctx.restoreGState()
        }

        if let knobStyle = ring.valueKnobStyle, value > minValue {
            let knobOffset = knobStyle.size / 2
            drawValueKnob(in: ctx, origin: CGPoint(x: innerPath.currentPoint.x - knobOffset,
                                                   y: innerPath.currentPoint.y - knobOffset))
        }
    }

    /// Updates the outer ring path depending on the ring's style
    private func updateOuterRingPath(_ path: UIBezierPath, radius: CGFloat, style: UICircularRingStyle) {
        switch style {
        case .dashed:
            path.setLineDash(ring.patternForDashes, count: ring.patternForDashes.count, phase: 0.0)

        case .dotted:
            path.setLineDash([0, path.lineWidth * 2], count: 2, phase: 0)
            path.lineCapStyle = .round

        case .bordered:
            let center: CGPoint = CGPoint(x: bounds.midX, y: bounds.midY)
            let offSet = max(ring.outerRingWidth, ring.innerRingWidth) / 2
                            + ((valueKnobStyle?.size ?? 0) / 4)
                            + (ring.outerBorderWidth * 2)
            let outerRadius: CGFloat = min(bounds.width, bounds.height) / 2 - offSet
            let borderStartAngle = ring.outerCapStyle == .butt ? ring.startAngle - ring.outerBorderWidth : ring.startAngle
            let borderEndAngle = ring.outerCapStyle == .butt ? ring.endAngle + ring.outerBorderWidth : ring.endAngle
            let start: CGFloat = ring.fullCircle ? 0 : borderStartAngle.toRads
            let end: CGFloat = ring.fullCircle ? .pi * 2 : borderEndAngle.toRads
            let borderPath = UIBezierPath(arcCenter: center,
                                          radius: outerRadius,
                                          startAngle: start,
                                          endAngle: end,
                                          clockwise: true)
            UIColor.clear.setFill()
            borderPath.fill()
            borderPath.lineWidth = (ring.outerBorderWidth * 2) + ring.outerRingWidth
            borderPath.lineCapStyle = ring.outerCapStyle
            ring.outerBorderColor.setStroke()
            borderPath.stroke()
        default:
            break
        }
    }

    /// Returns the end angle of the inner ring
    private func calculateInnerEndAngle() -> CGFloat {
        let innerEndAngle: CGFloat

        if ring.fullCircle {
            if !ring.isClockwise {
                innerEndAngle = ring.startAngle - ((value - minValue) / (maxValue - minValue) * 360.0)
            } else {
                innerEndAngle = (value - minValue) / (maxValue - minValue) * 360.0 + ring.startAngle
            }
        } else {
            // Calculate the center difference between the end and start angle
            let angleDiff: CGFloat = (ring.startAngle > ring.endAngle) ? (360.0 - ring.startAngle + ring.endAngle) : (ring.endAngle - ring.startAngle)
            // Calculate how much we should draw depending on the value set
            if !ring.isClockwise {
                innerEndAngle = ring.startAngle - ((value - minValue) / (maxValue - minValue) * angleDiff)
            } else {
                innerEndAngle = (value - minValue) / (maxValue - minValue) * angleDiff + ring.startAngle
            }
        }

        return innerEndAngle
    }

    /// Returns the raidus of the inner ring
    private func calculateInnerRadius() -> CGFloat {
        // The radius for style 1 is set below
        // The radius for style 1 is a bit less than the outer,
        // this way it looks like its inside the circle
        let radiusIn: CGFloat

        switch ring.ringStyle {
        case .inside:
            let difference = ring.outerRingWidth * 2 + ring.innerRingSpacing + (ring.valueKnobStyle?.size ?? 0) / 2
            let offSet = ring.innerRingWidth / 2 + (ring.valueKnobStyle?.size ?? 0) / 2
            radiusIn = (min(bounds.width - difference, bounds.height - difference) / 2) - offSet
        case .bordered:
            let offSet = (max(ring.outerRingWidth, ring.innerRingWidth) / 2)
                            + ((ring.valueKnobStyle?.size ?? 0) / 4)
                            + (ring.outerBorderWidth * 2)
            radiusIn = (min(bounds.width, bounds.height) / 2) - offSet
        default:
            let offSet = (max(ring.outerRingWidth, ring.innerRingWidth) / 2) + ((ring.valueKnobStyle?.size ?? 0) / 4)
            radiusIn = (min(bounds.width, bounds.height) / 2) - offSet
        }

        return radiusIn
    }

    /**
     Draws a gradient with a start and end position inside the provided context
     */
    private func drawGradient(_ gradient: CGGradient,
                              start: UICircularRingGradientPosition,
                              end: UICircularRingGradientPosition,
                              in context: CGContext) {

        context.drawLinearGradient(gradient,
                                   start: start.pointForPosition(in: bounds),
                                   end: end.pointForPosition(in: bounds),
                                   options: .drawsBeforeStartLocation)
    }

    /**
     Draws the value knob inside the provided context
     */
    private func drawValueKnob(in context: CGContext, origin: CGPoint) {
        guard let knobStyle = ring.valueKnobStyle else { return }

        context.saveGState()

        let rect = CGRect(origin: origin, size: CGSize(width: knobStyle.size, height: knobStyle.size))
        let knobPath = UIBezierPath(ovalIn: rect)

        context.setShadow(offset: knobStyle.shadowOffset,
                          blur: knobStyle.shadowBlur,
                          color: knobStyle.shadowColor.cgColor)
        context.addPath(knobPath.cgPath)
        context.setFillColor(knobStyle.color.cgColor)
        context.setLineCap(.round)
        context.setLineWidth(12)
        context.drawPath(using: .fill)

        context.restoreGState()
    }

    /**
     Draws the value label for the view.
     Only drawn if shouldShowValueText = true
     */
    func drawValueLabel() {
        guard ring.shouldShowValueText else { return }

        // Draws the text field
        // Some basic label properties are set
        valueLabel.font = ring.font
        valueLabel.textAlignment = .center
        valueLabel.textColor = ring.fontColor
        valueLabel.text = valueFormatter?.string(forValue: value)
        ring.willDisplayLabel(label: valueLabel)
        valueLabel.sizeToFit()

        // Deterime what should be the center for the label
        valueLabel.center = CGPoint(x: bounds.midX, y: bounds.midY)

        valueLabel.drawText(in: bounds)
    }
}
