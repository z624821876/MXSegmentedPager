// UICollectionView+MXSegmentedPager.m
//
// Copyright (c) 2015 Maxime Epain
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import <objc/runtime.h>
#import "UICollectionView+MXSegmentedPager.h"
#import "CSStickyHeaderFlowLayout.h"

@interface MXSegmentedPager ()
@property (nonatomic, strong) UICollectionView* parentView;
@property (nonatomic, strong) CSStickyHeaderFlowLayout *layout;
@end

@implementation MXSegmentedPager (UICollectionView)

static NSString * const reuseCellIdentifier     = @"Cell";
static NSString * const reuseHeaderIdentifier   = @"Header";
static NSString * const reuseSectionIdentifier  = @"Section";

static NSString * const contentOffsetKeyPath    = @"contentOffset";

- (CSStickyHeaderFlowLayout *) layout {
    CSStickyHeaderFlowLayout * layout = objc_getAssociatedObject(self, @selector(layout));
    if (!layout) {
        layout = [[CSStickyHeaderFlowLayout alloc] init];
        [self setLayout:layout];
    }
    return layout;
}

- (void) setLayout:(CSStickyHeaderFlowLayout *)layout {
    objc_setAssociatedObject(self, @selector(layout), layout, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (UICollectionView *)parentView {
    return objc_getAssociatedObject(self, @selector(parentView));
}

- (void)setParentView:(UICollectionView *)parentView {
    
    parentView.delegate = self;
    parentView.dataSource = self;
    parentView.alwaysBounceVertical = YES;
    parentView.showsVerticalScrollIndicator = NO;
    
    // Register classes
    [parentView registerClass:[UICollectionViewCell class] forCellWithReuseIdentifier:reuseCellIdentifier];
    [parentView registerClass:[UICollectionReusableView class] forSupplementaryViewOfKind:CSStickyHeaderParallaxHeader withReuseIdentifier:reuseHeaderIdentifier];
    [parentView registerClass:[UICollectionReusableView class] forSupplementaryViewOfKind:UICollectionElementKindSectionHeader withReuseIdentifier:reuseSectionIdentifier];
    
    parentView.collectionViewLayout = self.layout;
    
    objc_setAssociatedObject(self, @selector(parentView), parentView, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (UIView *)header {
    return objc_getAssociatedObject(self, @selector(header));
}

- (void)setHeader:(UIView *)header {
    [self setHeader:header withHeight:header.frame.size.height];
}

- (void) setHeader:(UIView *)header withHeight:(CGFloat)height {
    
    // Make sure the contentMode is set to scale proportionally
    [header setContentMode:UIViewContentModeScaleAspectFill];
    // Clip the parts of the view that are not in frame
    [header setClipsToBounds:YES];
    // Set the autoresizingMask to always be the same height as the header
    [header setAutoresizingMask:UIViewAutoresizingFlexibleHeight];
    
    objc_setAssociatedObject(self, @selector(header), header, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    self.layout.parallaxHeaderReferenceSize = CGSizeMake(self.frame.size.width, height);
    self.layout.itemSize = CGSizeMake(self.frame.size.width, self.layout.itemSize.height);
}

#pragma mark <UICollectionViewDelegate>
- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
    return 1;
}


- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return 1;
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    return self.containerSize;
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout referenceSizeForHeaderInSection:(NSInteger)section {
    return self.segmentedControl.frame.size;
}

#pragma mark <MXCollectionViewDelegateFlowLayout>

- (CGSize) collectionView:(UICollectionView *)collectionView headerSizeForLayout:(UICollectionViewLayout *)collectionViewLayout {
    return self.header.frame.size;
}

#pragma mark <UICollectionViewDataSource>

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    
    UICollectionViewCell* cell = [collectionView dequeueReusableCellWithReuseIdentifier:reuseCellIdentifier forIndexPath:indexPath];
    self.container.frame = (CGRect) {
        .origin = CGPointZero,
        .size   = self.containerSize
    };
    
    [self reloadData];
    [cell addSubview:self.container];
    [self setContentOffsetObserver];
    return cell;
}

- (UICollectionReusableView *)collectionView:(UICollectionView *)collectionView viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath {
    if ([kind isEqualToString:UICollectionElementKindSectionHeader]) {
        
        UICollectionReusableView* cell = [collectionView dequeueReusableSupplementaryViewOfKind:kind withReuseIdentifier:reuseSectionIdentifier forIndexPath:indexPath];
        [cell addSubview:self.segmentedControl];
        return cell;
        
    } else if ([kind isEqualToString:CSStickyHeaderParallaxHeader]) {
        UICollectionReusableView *cell = [collectionView dequeueReusableSupplementaryViewOfKind:kind withReuseIdentifier:reuseHeaderIdentifier forIndexPath:indexPath];
        [cell addSubview:self.header];
        return cell;
    }
    return nil;
}

#pragma mark - KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {

    if ([keyPath isEqualToString:contentOffsetKeyPath]) {
        
        if ([self.container.subviews containsObject:object] && [object isKindOfClass:[UIScrollView class]]) {
            [self layoutCollectionViewWithScrollView:object];
        }
    }
}

#pragma mark Private methods

- (void) setContentOffsetObserver {
    for (UIScrollView *view in self.container.subviews) {
        if ([view isKindOfClass:[UIScrollView class]]) {
            [view addObserver:self forKeyPath:contentOffsetKeyPath options:NSKeyValueObservingOptionNew context:nil];
        }
    }
}

- (void) layoutCollectionViewWithScrollView:(UIScrollView*) scrollView {
    
    CGFloat y = self.layout.parallaxHeaderReferenceSize.height;
    if (scrollView.contentOffset.y < self.layout.parallaxHeaderReferenceSize.height) {
        y = scrollView.contentOffset.y;
    }
    self.parentView.contentOffset = CGPointMake(self.parentView.contentOffset.x, y);
    
    NSLog(@"self.parentView.contentOffset (%f, %f)", self.parentView.contentOffset.x, self.parentView.contentOffset.y);
    NSLog(@"self.parentView.contentInset (%f, %f)", self.parentView.contentInset.top, self.parentView.contentInset.bottom);
}

@end

@implementation UICollectionView (MXSegmentedPager)

- (MXSegmentedPager *)segmentedPager {
    return objc_getAssociatedObject(self, @selector(segmentedPager));
}

- (void)setSegmentedPager:(MXSegmentedPager *)segmentedPager {
    
    segmentedPager.parentView = self;
    objc_setAssociatedObject(self, @selector(segmentedPager), segmentedPager, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (instancetype)initWithFrame:(CGRect)frame {
    CSStickyHeaderFlowLayout *layout= [[CSStickyHeaderFlowLayout alloc] init];
    return self = [self initWithFrame:frame collectionViewLayout:layout];
}

//- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer: (UIGestureRecognizer *)otherGestureRecognizer {
//    return YES;
//}

@end
