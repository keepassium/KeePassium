// Copyright 2018-2019 Yubico AB
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#import "YKFKVOObservation.h"
#import "YKFAssert.h"

static const int YKFKVOObservationContext = 0;

@interface YKFKVOObservation()

@property (nonatomic, weak) id target; // The target is not retained.
@property (nonatomic) NSString *keyPath;

@property (nonatomic, copy) YKFKVOObservationBlock callback;

@end

@implementation YKFKVOObservation

- (instancetype)initWithTarget:(id)target keyPath:(NSString *)keyPath callback:(YKFKVOObservationBlock)callback {
    YKFAssertAbortInit(target);
    YKFAssertAbortInit(keyPath);
    YKFAssertAbortInit(callback)
    
    self = [super init];
    if (self) {
        self.target = target;
        self.keyPath = keyPath;
        self.callback = callback;
        [self addObservation];
    }
    return self;
}

- (void)dealloc {
    YKFAssertReturn(self.target, @"The observation target was deallocated before removing the observation.");
    [self removeObservation];
}

#pragma mark - KVO

- (void)addObservation {
    [self.target addObserver:self forKeyPath:self.keyPath
                     options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld
                     context:(void *)&YKFKVOObservationContext];
}

- (void)removeObservation {
    [self.target removeObserver:self forKeyPath:self.keyPath
                        context:(void *)&YKFKVOObservationContext];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    if (context != &YKFKVOObservationContext) {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
        return;
    }
    
    YKFAssertReturn([keyPath isEqualToString:self.keyPath], @"Invalid KVO update from unknown keyPath.");
    
    id oldValue = change[NSKeyValueChangeOldKey];
    id newValue = change[NSKeyValueChangeNewKey];
    
    self.callback(oldValue, newValue);
}

@end
