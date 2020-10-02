//  KeePassium Password Manager
//  Copyright © 2020 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

public class ProgressObserver {
    internal let progress: ProgressEx
    private var progressFractionKVO: NSKeyValueObservation?
    private var progressDescriptionKVO: NSKeyValueObservation?
    
    init(progress: ProgressEx) {
        self.progress = progress
    }
    
    func startObservingProgress() {
        assert(progressFractionKVO == nil && progressDescriptionKVO == nil)
        progressFractionKVO = progress.observe(
            \.fractionCompleted,
            options: [.new],
            changeHandler: {
                [weak self] (progress, _) in
                self?.progressDidChange(progress: progress)
            }
        )
        progressDescriptionKVO = progress.observe(
            \.localizedDescription,
            options: [.new],
            changeHandler: {
                [weak self] (progress, _) in
                self?.progressDidChange(progress: progress)
            }
        )
    }
    
    func stopObservingProgress() {
        assert(progressFractionKVO != nil && progressDescriptionKVO != nil)
        progressFractionKVO?.invalidate()
        progressDescriptionKVO?.invalidate()
        progressFractionKVO = nil
        progressDescriptionKVO = nil
    }
    
    func progressDidChange(progress: ProgressEx) {
        assertionFailure("Override this")
    }
}
