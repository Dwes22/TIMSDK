//
//  TUIChatDefine.h
//  Pods
//
//  Created by xiangzhang on 2022/10/14.
//

#import <TIMCommon/TIMCommonModel.h>

#ifndef TUIGroupDefine_h
#define TUIGroupDefine_h

typedef NS_ENUM(NSInteger, TUISelectMemberOptionalStyle) {
    TUISelectMemberOptionalStyleNone            = 0,
    TUISelectMemberOptionalStyleAtAll           = 1 << 0,
    TUISelectMemberOptionalStyleTransferOwner   = 1 << 1,
    TUISelectMemberOptionalStylePublicMan       = 1 << 2
};

typedef void(^SelectedFinished)(NSMutableArray <TUIUserModel *> *modelList);

#endif /* TUIGroupDefine_h */
