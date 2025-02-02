//
//  TUIBaseChatViewController_Minimalist.m
//  UIKit
//
//  Created by annidyfeng on 2019/5/21.
//

#import "TUIBaseChatViewController_Minimalist.h"
#import <MobileCoreServices/MobileCoreServices.h>
#import <AVFoundation/AVFoundation.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import <Photos/Photos.h>
#import "ReactiveObjC/ReactiveObjC.h"
#import "TUIBaseMessageController_Minimalist.h"
#import "TUIImageMessageCellData_Minimalist.h"
#import "TUIVideoMessageCellData_Minimalist.h"
#import "TUIFileMessageCellData_Minimalist.h"
#import "TUIVoiceMessageCellData_Minimalist.h"
#import "TUITextMessageCellData_Minimalist.h"
#import "TUIReplyMessageCellData_Minimalist.h"
#import <TIMCommon/TIMDefine.h>
#import "TUIMessageMultiChooseView_Minimalist.h"
#import "TUIMessageController_Minimalist.h"
#import "TUIChatDataProvider_Minimalist.h"
#import "TUIMessageDataProvider_Minimalist.h"
#import "TUICameraViewController.h"
#import <TUICore/TUITool.h>
#import <TUICore/TUICore.h>
#import <TIMCommon/TIMDefine.h>
#import <TUICore/NSDictionary+TUISafe.h>
#import <TIMCommon/NSString+TUIEmoji.h>
#import <TUICore/TUIThemeManager.h>
#import "TUIChatMediaDataProvider.h"
#import "TUIMessageReadViewController_Minimalist.h"
#import "TUIJoinGroupMessageCell_Minimalist.h"
#import "TUICloudCustomDataTypeCenter.h"
#import <TUICore/TUILogin.h>
#import "TUIChatConfig.h"
#import "TUIChatModifyMessageHelper.h"
#import "TUIChatMembersReactController.h"
#import "TUIAIDenoiseSignatureManager.h"
#import <TIMCommon/TUIBubbleMessageCell_Minimalist.h>
#import <TIMCommon/TUIFloatViewController.h>
#import "UIAlertController+TUICustomStyle.h"

static UIView *customTopView;

@interface TUIBaseChatViewController_Minimalist () <TUIBaseMessageControllerDelegate_Minimalist,
                                                    TUIInputControllerDelegate_Minimalist,
                                                    UIImagePickerControllerDelegate,
                                                    UIDocumentPickerDelegate,
                                                    UINavigationControllerDelegate,
                                                    TUIMessageMultiChooseViewDelegate_Minimalist,
                                                    TUIChatBaseDataProviderDelegate,
                                                    TUINotificationProtocol,
                                                    TUIJoinGroupMessageCellDelegate_Minimalist,
                                                    V2TIMConversationListener,
                                                    TUINavigationControllerDelegate,
                                                    V2TIMSDKListener,
                                                    TUIChatMediaDataListener>

@property (nonatomic, strong) TUINaviBarIndicatorView *titleView;
@property (nonatomic, strong) TUIMessageMultiChooseView_Minimalist *multiChooseView;
@property (nonatomic, assign) BOOL responseKeyboard;
@property (nonatomic, strong) TUIChatDataProvider_Minimalist *dataProvider;

@property (nonatomic, weak) UIViewController *forwardConversationSelectVC;
@property (nonatomic) NSArray<TUIMessageCellData *> *forwardSelectUIMsgs;
@property (nonatomic) BOOL isMergeForward;

@property (nonatomic, assign) BOOL firstAppear;

@property (nonatomic, copy) NSString *mainTitle;

@property (nonatomic, strong) UIImageView *backgroudView;

@property (nonatomic, strong) UIImageView *avatarView;

@property (nonatomic, strong) UILabel *mainTitleLabel;

@property (nonatomic, strong) UILabel *subTitleLabel;

@property (nonatomic, copy) NSString *forwardText;

@property (nonatomic, strong) TUIChatMediaDataProvider *mediaProvider;

@end

@implementation TUIBaseChatViewController_Minimalist

#pragma mark - Life Cycle
- (instancetype)init {
    self = [super init];
    if (self) {
        [TUIBaseChatViewController_Minimalist createCachePath];
        [[TUIAIDenoiseSignatureManager sharedInstance] updateSignature];
    }
    return self;
}

- (void)setTitle:(NSString *)title {
    self.mainTitle = title;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.firstAppear = YES;
    self.view.backgroundColor = TIMCommonDynamicColor(@"controller_bg_color", @"#FFFFFF");
    self.edgesForExtendedLayout = UIRectEdgeNone;

    [self configBackgroundView];
    
    [self configNotify];

    // setup UI
    [self setupNavigator];
    if (customTopView) {
        [self setupCustomTopView];
    }
    [self setupMessageController];
    [self setupInputController];
    
    // data provider
    self.dataProvider = [[TUIChatDataProvider_Minimalist alloc] init];
    self.dataProvider.delegate = self;
    
    [[V2TIMManager sharedInstance] addIMSDKListener:self];
}

- (void)dealloc {
    [TUICore unRegisterEventByObject:self];
}

- (void)willMoveToParentViewController:(UIViewController *)parent {
    if (parent == nil) {
        [self saveDraft];
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    if (customTopView) {
        [self setupCustomTopView];
    }
}
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    self.responseKeyboard = YES;
    if (self.firstAppear) {
        [self loadDraft];
        self.firstAppear = NO;
    }
    self.mainTitleLabel.text = [self getMainTitleLabelText];
    [self.avatarView sd_setImageWithURL:[NSURL URLWithString:self.conversationData.faceUrl] placeholderImage:self.conversationData.avatarImage];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    self.responseKeyboard = NO;
    [self openMultiChooseBoard:NO];
    [self.messageController enableMultiSelectedMode:NO];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    
    if (self.inputController.status == Input_Status_Input ||
        self.inputController.status == Input_Status_Input_Keyboard) {
        CGPoint offset = self.messageController.tableView.contentOffset;
        __weak typeof(self) weakSelf = self;
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf)strongSelf = weakSelf;
            strongSelf.responseKeyboard = YES;
            [UIApplication.sharedApplication.keyWindow endEditing:YES];
            [strongSelf inputController:strongSelf.inputController didChangeHeight:CGRectGetMaxY(strongSelf.inputController.inputBar.frame) + Bottom_SafeHeight];
            [strongSelf.messageController.tableView setContentOffset:offset];
        });
    }
}

- (void)setupNavigator {
    TUINavigationController *naviController = (TUINavigationController *)self.navigationController;
    if ([naviController isKindOfClass:TUINavigationController.class]) {
        naviController.uiNaviDelegate = self;
    }
   
    UIButton *backButton = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, 24, 24)];
    [backButton addTarget:self action:@selector(backButtonClick) forControlEvents:UIControlEventTouchUpInside];
    [backButton setImage:[[TUIImageCache sharedInstance] getResourceFromCache:TUIChatImagePath_Minimalist(@"vc_back")] forState:UIControlStateNormal];
    UIBarButtonItem *backButtonItem = [[UIBarButtonItem alloc] initWithCustomView:backButton];
    
    UIView *infoView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, kScale390(200), 40)];
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(rightBarButtonClick)];
    [infoView addGestureRecognizer:tap];
    
    UIImageView *avatarView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 40, 40)];
    avatarView.image = self.conversationData.avatarImage;
    avatarView.layer.cornerRadius = avatarView.frame.size.width / 2.0;
    avatarView.layer.masksToBounds = YES;
    [infoView addSubview:avatarView];
    self.avatarView = avatarView;
    
    UILabel *mainTitleLabel = [[UILabel alloc] initWithFrame:CGRectMake(avatarView.mm_x + avatarView.mm_w + kScale390(8), 0, kScale390(200), 20)];
    mainTitleLabel.font = [UIFont boldSystemFontOfSize:14];
    mainTitleLabel.text = [self getMainTitleLabelText];
    [infoView addSubview:mainTitleLabel];
    self.mainTitleLabel = mainTitleLabel;
    
    self.subTitleLabel = [[UILabel alloc] initWithFrame:CGRectMake(mainTitleLabel.mm_x, 20, mainTitleLabel.mm_w, 20)];
    self.subTitleLabel.font = [UIFont systemFontOfSize:12];
    [self updateSubTitleLabelText];
    [infoView addSubview:self.subTitleLabel];
    UIBarButtonItem *infoViewItem = [[UIBarButtonItem alloc] initWithCustomView:infoView];

    self.navigationItem.leftBarButtonItems = @[backButtonItem, infoViewItem];
    
    CGSize itemSize = CGSizeMake(30, 24);
    NSMutableArray *rightBarButtonList = [NSMutableArray array];
    NSMutableDictionary *param = [NSMutableDictionary dictionary];
    if (self.conversationData.userID.length > 0) {
        param[TUICore_TUIChatExtension_NavigationMoreItem_UserID] = self.conversationData.userID;
    } else if (self.conversationData.groupID.length > 0) {
        param[TUICore_TUIChatExtension_NavigationMoreItem_GroupID] = self.conversationData.groupID;
    }
    param[TUICore_TUIChatExtension_NavigationMoreItem_ItemSize] = NSStringFromCGSize(itemSize);
    param[TUICore_TUIChatExtension_NavigationMoreItem_FilterVideoCall] = @(!TUIChatConfig.defaultConfig.enableVideoCall);
    param[TUICore_TUIChatExtension_NavigationMoreItem_FilterAudioCall] = @(!TUIChatConfig.defaultConfig.enableAudioCall);
    NSArray<TUIExtensionInfo *> *extensionList = [TUICore getExtensionList:TUICore_TUIChatExtension_NavigationMoreItem_MinimalistExtensionID param:param];
    for (TUIExtensionInfo *info in extensionList) {
        if (info.icon && info.onClicked) {
            UIButton *button = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, itemSize.width, itemSize.height)];
            button.tui_extValueObj = info;
            [button addTarget:self action:@selector(rightBarButtonClick:) forControlEvents:UIControlEventTouchUpInside];
            [button setImage:info.icon forState:UIControlStateNormal];
            UIBarButtonItem *rightItem = [[UIBarButtonItem alloc] initWithCustomView:button];
            [rightBarButtonList addObject:rightItem];
        }
    }
    if (rightBarButtonList.count > 0) {
        self.navigationItem.rightBarButtonItems = rightBarButtonList.reverseObjectEnumerator.allObjects;
    }
}

- (NSString *)getMainTitleLabelText {
    if (self.conversationData.title.length > 0) {
        return self.conversationData.title;
    } else if (self.conversationData.groupID.length > 0) {
        return self.conversationData.groupID;
    } else {
        return self.conversationData.userID;
    }
}

- (void)updateSubTitleLabelText {
    if (self.conversationData.userID.length > 0) {
        [[V2TIMManager sharedInstance] getUserStatus:@[self.conversationData.userID] succ:^(NSArray<V2TIMUserStatus *> *result) {
            V2TIMUserStatus *status = result.firstObject;
            self.subTitleLabel.text = [self getUserStatus:status];
        } fail:nil];
    } else if(self.conversationData.groupID.length > 0) {
        [[V2TIMManager sharedInstance] getGroupMemberList:self.conversationData.groupID filter:V2TIM_GROUP_MEMBER_FILTER_ALL nextSeq:0 succ:^(uint64_t nextSeq, NSArray<V2TIMGroupMemberFullInfo *> *memberList) {
            NSMutableString *title = [NSMutableString string];
            int memberCount = 0;
            for (V2TIMGroupMemberFullInfo *info in memberList) {
                NSString *name = (info.nameCard?:info.nickName)?:info.userID;
                [title appendString:[NSString stringWithFormat:@"%@，", name]];
                if (++memberCount >= 5) {
                    break;
                }
            }
            if (title.length > 0) {
                title = [NSMutableString stringWithString:[title substringToIndex:title.length - 1]];
            }
            self.subTitleLabel.text = title;
        } fail:nil];
    }
}

- (void)onUserStatusChanged:(NSArray<V2TIMUserStatus *> *)userStatusList {
    if (!self.conversationData.userID) {
        return;
    }
    for (V2TIMUserStatus *status in userStatusList) {
        if ([status.userID isEqualToString:self.conversationData.userID]) {
            self.subTitleLabel.text = [self getUserStatus:status];
            break;
        }
    }
}

- (NSString *)getUserStatus:(V2TIMUserStatus *)status {
    NSString *title = nil;
    switch (status.statusType) {
        case V2TIM_USER_STATUS_UNKNOWN:
            {
                title = TIMCommonLocalizableString(TUIKitUserStatusUnknown);
            }
            break;
        case V2TIM_USER_STATUS_ONLINE:
            {
                title = TIMCommonLocalizableString(TUIKitUserStatusOnline);
            }
            break;
        case V2TIM_USER_STATUS_OFFLINE:
            {
                title = TIMCommonLocalizableString(TUIKitUserStatusOffline);
            }
            break;
        case V2TIM_USER_STATUS_UNLOGINED:
            {
                title = TIMCommonLocalizableString(TUIKitUserStatusUnlogined);
            }
            break;
        default:
            break;
    }
    return title;
}

- (void)backButtonClick {
    [self.messageController readReport];
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)rightBarButtonClick:(UIButton *)button {
    TUIExtensionInfo *info = button.tui_extValueObj;
    if (info == nil || ![info isKindOfClass:TUIExtensionInfo.class] || info.onClicked == nil) {
        return;
    }
    NSMutableDictionary *param = [NSMutableDictionary dictionary];
    if (self.conversationData.userID.length > 0) {
        param[TUICore_TUIChatExtension_NavigationMoreItem_UserID] = self.conversationData.userID;
    } else if (self.conversationData.groupID.length > 0) {
        param[TUICore_TUIChatExtension_NavigationMoreItem_GroupID] = self.conversationData.groupID;
    }
    
    if (self.navigationController) {
        param[TUICore_TUIChatExtension_NavigationMoreItem_PushVC] = self.navigationController;
    }
    info.onClicked(param);
}

- (void)setupMessageController {
    TUIMessageController_Minimalist *vc = [[TUIMessageController_Minimalist alloc] init];
    vc.hightlightKeyword = self.highlightKeyword;
    vc.locateMessage = self.locateMessage;
    vc.isMsgNeedReadReceipt = [TUIChatConfig defaultConfig].msgNeedReadReceipt;
    _messageController = vc;
    _messageController.delegate = self;
    [_messageController setConversation:self.conversationData];
    _messageController.view.frame = CGRectMake(0,  [self topMarginByCustomView],
                                               self.view.frame.size.width,
                                               self.view.frame.size.height - TTextView_Height - Bottom_SafeHeight - [self topMarginByCustomView]);
    [self addChildViewController:_messageController];
    [self.view addSubview:_messageController.view];
    [_messageController didMoveToParentViewController:self];
}

- (void)setupCustomTopView {
    [self.view addSubview:customTopView];
    customTopView.mm_top(0).mm_left(0);
}

- (void)setupInputController {
    _inputController = [[TUIInputController_Minimalist alloc] init];
    _inputController.delegate = self;
    _inputController.view.frame = CGRectMake(0, self.view.frame.size.height - TTextView_Height - Bottom_SafeHeight, self.view.frame.size.width, TTextView_Height + Bottom_SafeHeight);
    _inputController.view.autoresizingMask = UIViewAutoresizingFlexibleTopMargin;
    [self addChildViewController:_inputController];
    [self.view addSubview:_inputController.view];
}

- (void)configBackgroundView {
    self.backgroudView = [[UIImageView alloc] init];
    self.backgroudView.backgroundColor = TUIChatConfig.defaultConfig.backgroudColor ? TUIChatConfig.defaultConfig.backgroudColor : TUIChatDynamicColor(@"chat_controller_bg_color", @"#FFFFFF");
    NSString *conversationID = [self getConversationID];
    NSString *imgUrl = [self getBackgroundImageUrlByConversationID:conversationID];

    if (TUIChatConfig.defaultConfig.backgroudImage) {
        self.backgroudView.backgroundColor = UIColor.clearColor;
        self.backgroudView.image = TUIChatConfig.defaultConfig.backgroudImage;
    }
    else if (IS_NOT_EMPTY_NSSTRING(imgUrl)) {
        [self.backgroudView sd_setImageWithURL:[NSURL URLWithString:imgUrl] placeholderImage:nil];
    }
    self.backgroudView.frame = CGRectMake(0, self.view.frame.origin.y, self.view.frame.size.width, self.view.frame.size.height - TTextView_Height - Bottom_SafeHeight);
    
    [self.view insertSubview:self.backgroudView atIndex:0];
}

- (void)configNotify {

    [[V2TIMManager sharedInstance] addConversationListener:self];
    [TUICore registerEvent:TUICore_TUIConversationNotify subKey:TUICore_TUIConversationNotify_SelectConversationSubKey object:self];
    [TUICore registerEvent:TUICore_TUIConversationNotify subKey:TUICore_TUIConversationNotify_ClearConversationUIHistorySubKey object:self];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(onFriendInfoChanged:) name:@"FriendInfoChangedNotification" object:nil];

    [TUICore registerEvent:TUICore_TUIContactNotify subKey:TUICore_TUIContactNotify_UpdateConversationBackgroundImageSubKey object:self];
    [TUICore registerEvent:TUICore_TUIGroupNotify subKey:TUICore_TUIGroupNotify_UpdateConversationBackgroundImageSubKey object:self];

}

#pragma mark - Public Methods

- (void)sendMessage:(V2TIMMessage *)message {
    [self.messageController sendMessage:message];
}

- (void)saveDraft {
    NSString *content = [self.inputController.inputBar.inputTextView.textStorage getPlainString];
    
    TUIReplyPreviewData_Minimalist * previewData = nil;
    if (self.inputController.referenceData) {
        previewData  = self.inputController.referenceData;
    }
    else if(self.inputController.replyData) {
        previewData  = self.inputController.replyData;
    }
    if (previewData) {
        
        NSDictionary *dict = @{
            @"content" : content?:@"",
            @"messageReply" : @{
                    @"messageID"       : previewData.msgID?:@"",
                    @"messageAbstract" : [previewData.msgAbstract?:@"" getInternationalStringWithfaceContent],
                    @"messageSender"   : previewData.sender?:@"",
                    @"messageType"     : @(previewData.type),
                    @"messageTime"     : @(previewData.originMessage.timestamp ? [previewData.originMessage.timestamp timeIntervalSince1970] : 0),  // Compatible for web
                    @"messageSequence" : @(previewData.originMessage.seq),// Compatible for web
                    @"version"         : @(kDraftMessageReplyVersion),
            },
        };
        NSMutableDictionary *mudic = [NSMutableDictionary dictionaryWithDictionary:dict];
        
        if (IS_NOT_EMPTY_NSSTRING(previewData.messageRootID)) {
            [mudic setObject:previewData.messageRootID forKey:@"messageRootID"];
        }
        NSError *error = nil;
        NSData *data = [NSJSONSerialization dataWithJSONObject:mudic options:0 error:&error];
        if (error == nil) {
            content = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        }
    }
    [TUIChatDataProvider_Minimalist saveDraftWithConversationID:self.conversationData.conversationID Text:content];

}

- (void)loadDraft {
    NSString *draft = self.conversationData.draftText;
    if (draft.length == 0) {
        return;
    }
    
    NSError *error = nil;
    NSDictionary *jsonDict = [NSJSONSerialization JSONObjectWithData:[draft dataUsingEncoding:NSUTF8StringEncoding] options:0 error:&error];
    if (error || jsonDict == nil) {
                
        NSMutableAttributedString *formatEmojiString = [draft getAdvancedFormatEmojiStringWithFont:kTUIInputNoramlFont textColor:kTUIInputNormalTextColor emojiLocations:nil];

        
        [self.inputController.inputBar.inputTextView.textStorage insertAttributedString:formatEmojiString atIndex:0];
        return;
    }
    
    /**
     * 显示草稿
     * Display draft
     */
    NSString *draftContent = [jsonDict.allKeys containsObject:@"content"] ? jsonDict[@"content"] : @"";
    
    NSMutableAttributedString *formatEmojiString = [draftContent getAdvancedFormatEmojiStringWithFont:kTUIInputNoramlFont textColor:kTUIInputNormalTextColor emojiLocations:nil];

    [self.inputController.inputBar.inputTextView.textStorage insertAttributedString:formatEmojiString atIndex:0];
    
    NSString *messageRootID = [jsonDict.allKeys containsObject:@"messageRootID"] ? jsonDict[@"messageRootID"] : @"";

    /**
     * 显示消息回复预览
     * Display message reply preview bar
     */
    if ([jsonDict isKindOfClass:NSDictionary.class] && [jsonDict.allKeys containsObject:@"messageReply"]) {
        NSDictionary *reply = jsonDict[@"messageReply"];
        if ([reply isKindOfClass:NSDictionary.class] &&
            [reply.allKeys containsObject:@"messageID"] &&
            [reply.allKeys containsObject:@"messageAbstract"] &&
            [reply.allKeys containsObject:@"messageSender"] &&
            [reply.allKeys containsObject:@"messageType"] &&
            [reply.allKeys containsObject:@"version"]) {
            NSInteger version = [reply[@"version"] integerValue];
            if (version <= kDraftMessageReplyVersion) {

                if (IS_NOT_EMPTY_NSSTRING(messageRootID)) {
                    TUIReplyPreviewData_Minimalist *replyData = [[TUIReplyPreviewData_Minimalist alloc] init];
                    replyData.msgID       = reply[@"messageID"];
                    replyData.msgAbstract = reply[@"messageAbstract"];
                    replyData.sender      = reply[@"messageSender"];
                    replyData.type        = [reply[@"messageType"] integerValue];
                    replyData.messageRootID = messageRootID;
                    [self.inputController showReplyPreview:replyData];
                }
                else {
                    TUIReferencePreviewData_Minimalist *replyData = [[TUIReferencePreviewData_Minimalist alloc] init];
                    replyData.msgID       = reply[@"messageID"];
                    replyData.msgAbstract = reply[@"messageAbstract"];
                    replyData.sender      = reply[@"messageSender"];
                    replyData.type        = [reply[@"messageType"] integerValue];
                    [self.inputController showReferencePreview:replyData];
                }
            }
        }
    }
}

+ (void)setCustomTopView:(UIView *)view {
    customTopView = view;
}

+ (UIView *)customTopView {
    return customTopView;
}

#pragma mark - Getters & Setters

- (void)setConversationData:(TUIChatConversationModel *)conversationData {
    _conversationData = conversationData;
}

- (CGFloat)topMarginByCustomView {
    return customTopView ? customTopView.mm_h: 0;
}

#pragma mark - Event Response

- (void)checkTitle:(BOOL)force {
    
    if (force || self.conversationData.title.length == 0) {
        if (self.conversationData.userID.length > 0) {
            self.conversationData.title = self.conversationData.userID;
            @weakify(self);
            
            [TUIChatDataProvider_Minimalist getFriendInfoWithUserId:self.conversationData.userID
                                             SuccBlock:^(V2TIMFriendInfoResult * _Nonnull friendInfoResult) {
                @strongify(self);
                if (friendInfoResult.relation & V2TIM_FRIEND_RELATION_TYPE_IN_MY_FRIEND_LIST
                    && friendInfoResult.friendInfo.friendRemark.length > 0) {
                    self.conversationData.title = friendInfoResult.friendInfo.friendRemark;
                } else {
                    [TUIChatDataProvider_Minimalist getUserInfoWithUserId:friendInfoResult.friendInfo.userID
                                                   SuccBlock:^(V2TIMUserFullInfo * _Nonnull userInfo) {
                        if (userInfo.nickName.length > 0) {
                            self.conversationData.title = userInfo.nickName;
                        }
                    } failBlock:nil];
                }
            } failBlock:nil];
        }
        else if (self.conversationData.groupID.length > 0) {
            [TUIChatDataProvider_Minimalist getGroupInfoWithGroupID:self.conversationData.groupID
                                             SuccBlock:^(V2TIMGroupInfoResult * _Nonnull groupResult) {
                if (groupResult.info.groupName.length > 0) {
                    self.conversationData.title = groupResult.info.groupName;
                }
            } failBlock:nil];
        }
    }
}

-(void)leftBarButtonClick {
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)rightBarButtonClick {
    if (_conversationData.userID.length > 0) {
        
        [self getUserOrFriendProfileVCWithUserID:self.conversationData.userID
                                       succBlock:^(UIViewController * _Nonnull vc) {
            [self.navigationController pushViewController:vc animated:YES];
        } failBlock:^(int code, NSString * _Nonnull desc) {
            [TUITool makeToastError:code msg:desc];
        }];
    } else {
        NSDictionary *param = @{
            TUICore_TUIGroupObjectFactory_GetGroupInfoControllerMethod_GroupIDKey: self.conversationData.groupID
        };
        UIViewController *vc = [TUICore createObject:TUICore_TUIGroupObjectFactory_Minimalist key:TUICore_TUIGroupObjectFactory_GetGroupInfoControllerMethod param:param];
        [self.navigationController pushViewController:vc animated:YES];
    }
}

- (void)getUserOrFriendProfileVCWithUserID:(NSString *)userID
                                 succBlock:(void(^)(UIViewController *vc))succ
                                 failBlock:(nullable V2TIMFail)fail {
    NSDictionary *param = @{
        TUICore_TUIContactObjectFactory_GetUserOrFriendProfileVCMethod_UserIDKey: userID ? : @"",
        TUICore_TUIContactObjectFactory_GetUserOrFriendProfileVCMethod_SuccKey: succ ? : ^(UIViewController *vc){},
        TUICore_TUIContactObjectFactory_GetUserOrFriendProfileVCMethod_FailKey: fail ? : ^(int code, NSString * desc){}
    };
    [TUICore createObject:TUICore_TUIContactObjectFactory_Minimalist key:TUICore_TUIContactObjectFactory_GetUserOrFriendProfileVCMethod param:param];
}

#pragma mark - TUICore notify

- (void)onNotifyEvent:(NSString *)key subKey:(NSString *)subKey object:(id)anObject param:(NSDictionary *)param {
    if ([key isEqualToString:TUICore_TUIConversationNotify]
        && [subKey isEqualToString:TUICore_TUIConversationNotify_SelectConversationSubKey]
        && self.forwardConversationSelectVC == anObject) {
        NSArray<NSDictionary *> *selectList = param[TUICore_TUIConversationNotify_SelectConversationSubKey_ConversationListKey];
        
        NSMutableArray<TUIChatConversationModel *> *targetList = [NSMutableArray arrayWithCapacity:selectList.count];
        for (NSDictionary *selectItem in selectList) {
            TUIChatConversationModel *model = [TUIChatConversationModel new];
            model.title = selectItem[TUICore_TUIConversationNotify_SelectConversationSubKey_ItemTitleKey];
            model.userID = selectItem[TUICore_TUIConversationNotify_SelectConversationSubKey_ItemUserIDKey];
            model.groupID = selectItem[TUICore_TUIConversationNotify_SelectConversationSubKey_ItemGroupIDKey];
            model.conversationID = selectItem[TUICore_TUIConversationNotify_SelectConversationSubKey_ItemConversationIDKey];
            [targetList addObject:model];
        }
        
        [self forwardMessages:self.forwardSelectUIMsgs toTargets:targetList merge:self.isMergeForward];
        self.forwardSelectUIMsgs = nil;
        
        if (self.forwardText.length > 0) {
            [self forwardText:self.forwardText toConverations:targetList];
            self.forwardText = nil;
        }
    }
    
    else if ([key isEqualToString:TUICore_TUIConversationNotify] && [subKey isEqualToString:TUICore_TUIConversationNotify_ClearConversationUIHistorySubKey]) {
        [self.messageController clearUImsg];
    }
    else if ([key isEqualToString:TUICore_TUIContactNotify]
             && [subKey isEqualToString:TUICore_TUIContactNotify_UpdateConversationBackgroundImageSubKey]) {
        NSString *conversationID = param[TUICore_TUIContactNotify_UpdateConversationBackgroundImageSubKey_ConversationID];
        if (IS_NOT_EMPTY_NSSTRING(conversationID)) {
            [self updateBackgroundImageUrlByConversationID:conversationID];
        }
    }
    else if ([key isEqualToString:TUICore_TUIGroupNotify]
             && [subKey isEqualToString:TUICore_TUIGroupNotify_UpdateConversationBackgroundImageSubKey]) {
        NSString *conversationID = param[TUICore_TUIGroupNotify_UpdateConversationBackgroundImageSubKey_ConversationID];
        if (IS_NOT_EMPTY_NSSTRING(conversationID)) {
            [self updateBackgroundImageUrlByConversationID:conversationID];
        }
    }
    
}

- (void)updateBackgroundImageUrlByConversationID:(NSString *)conversationID {
    if ([[self getConversationID]  isEqualToString:conversationID]) {
        self.backgroudView.backgroundColor = UIColor.clearColor;
        NSString *imgUrl = [self getBackgroundImageUrlByConversationID:conversationID];
        if (IS_NOT_EMPTY_NSSTRING(imgUrl)) {
             [self.backgroudView sd_setImageWithURL:[NSURL URLWithString:imgUrl] placeholderImage:nil];
        }
        else {
            self.backgroudView.image = nil;
        }
    }
}

- (NSString *)getBackgroundImageUrlByConversationID:(NSString *)targerConversationID {
    if (targerConversationID.length == 0) {
        return nil;
    }
    NSDictionary *dict = [NSUserDefaults.standardUserDefaults objectForKey:@"conversation_backgroundImage_map"];
    if (dict == nil) {
        dict = @{};
    }
    NSString *conversationID_UserID = [NSString stringWithFormat:@"%@_%@",targerConversationID,[TUILogin getUserID]];
    if (![dict isKindOfClass:NSDictionary.class] || ![dict.allKeys containsObject:conversationID_UserID]) {
        return nil;
    }
    return [dict objectForKey:conversationID_UserID];
}

- (NSString *)getConversationID {
    NSString *conversationID = @"";
    if (self.conversationData.conversationID.length > 0) {
        conversationID = self.conversationData.conversationID;
    }
    else if (self.conversationData.userID.length > 0) {
        conversationID = [NSString stringWithFormat:@"c2c_%@",self.conversationData.userID];
    }
    else if (self.conversationData.groupID.length > 0) {
        conversationID = [NSString stringWithFormat:@"group_%@",self.conversationData.groupID];
    }
    return conversationID;
}

#pragma mark - TUIInputControllerDelegate
- (void)inputController:(TUIInputController_Minimalist *)inputController didChangeHeight:(CGFloat)height {
    if (!self.responseKeyboard) {
        return;
    }
    [UIView animateWithDuration:0.3 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
        CGRect msgFrame = self.messageController.view.frame;
        msgFrame.size.height = self.view.frame.size.height - height - [self topMarginByCustomView];
        self.messageController.view.frame = msgFrame;

        CGRect inputFrame = self.inputController.view.frame;
        inputFrame.origin.y = msgFrame.origin.y + msgFrame.size.height;
        inputFrame.size.height = height;
        self.inputController.view.frame = inputFrame;
        [self.messageController scrollToBottom:NO];
    } completion:nil];
}

- (void)inputController:(TUIInputController_Minimalist *)inputController didSendMessage:(V2TIMMessage *)msg {
    [self.messageController sendMessage:msg];
}

- (void)inputControllerDidSelectMoreButton:(TUIInputController_Minimalist *)inputController {
    NSArray *items = [self.dataProvider getInputMoreActionItemList:self.conversationData.userID
                                                           groupID:self.conversationData.groupID
                                                            pushVC:self.navigationController];
    if (items.count) {
        UIAlertController *alertVC = [UIAlertController alertControllerWithTitle:nil message:nil preferredStyle:UIAlertControllerStyleActionSheet];
        [alertVC configItems:items];
        [alertVC addAction:[UIAlertAction actionWithTitle:TIMCommonLocalizableString(Cancel) style:UIAlertActionStyleCancel handler:nil]];
        [self presentViewController:alertVC animated:YES completion:nil];
    }
}

- (void)inputControllerDidSelectCamera:(TUIInputController_Minimalist *)inputController {
    [self.mediaProvider takePicture];
}

- (void)inputControllerDidInputAt:(TUIInputController_Minimalist *)inputController {
    /**
     * 交给 GroupChatVC 去处理
     * Handle to GroupChatVC
     */
}

- (void)inputController:(TUIInputController_Minimalist *)inputController didDeleteAt:(NSString *)atText {
    /**
     * 交给 GroupChatVC 去处理
     * Handle to GroupChatVC
     */
}

- (void)inputControllerBeginTyping:(TUIInputController_Minimalist *)inputController {
    //for C2CChatVC
}

- (void)inputControllerEndTyping:(TUIInputController_Minimalist *)inputController {
    //for C2CChatVC
}

#pragma mark - TUIBaseMessageControllerDelegate
- (void)didTapInMessageController:(TUIBaseMessageController_Minimalist *)controller {
    [self.inputController reset];
}

- (BOOL)messageController:(TUIBaseMessageController_Minimalist *)controller willShowMenuInCell:(TUIMessageCell *)cell {
    if([self.inputController.inputBar.inputTextView isFirstResponder]){
        self.inputController.inputBar.inputTextView.overrideNextResponder = cell;
        return YES;
    }
    return NO;
}

- (TUIMessageCellData *)messageController:(TUIBaseMessageController_Minimalist *)controller onNewMessage:(V2TIMMessage *)message {
    return nil;
}

- (TUIMessageCell *)messageController:(TUIBaseMessageController_Minimalist *)controller onShowMessageData:(TUIMessageCellData *)data {
    return nil;
}

- (void)messageController:(TUIBaseMessageController_Minimalist *)controller willDisplayCell:(TUIMessageCell *)cell withData:(TUIMessageCellData *)cellData {
    if([cell isKindOfClass:[TUIJoinGroupMessageCell_Minimalist class]]){
        TUIJoinGroupMessageCell_Minimalist *joinCell = (TUIJoinGroupMessageCell_Minimalist *)cell;
        joinCell.joinGroupDelegate = self;
    }
}

- (void)messageController:(TUIBaseMessageController_Minimalist *)controller onSelectMessageAvatar:(TUIMessageCell *)cell {
    if (cell.messageData.identifier == nil) {
        return;
    }
    [self getUserOrFriendProfileVCWithUserID:cell.messageData.identifier
                                   succBlock:^(UIViewController *vc) {
        [self.navigationController pushViewController:vc animated:YES];
    } failBlock:nil];
}

- (void)messageController:(TUIBaseMessageController_Minimalist *)controller onSelectMessageContent:(TUIMessageCell *)cell {
    cell.disableDefaultSelectAction = NO;
    if (cell.disableDefaultSelectAction) {
        return;
    }
}

- (void)messageController:(TUIBaseMessageController_Minimalist *)controller onSelectMessageMenu:(NSInteger)menuType withData:(TUIMessageCellData *)data {
    [self onSelectMessageMenu:menuType withData:data];
}

- (void)didHideMenuInMessageController:(TUIBaseMessageController_Minimalist *)controller {
    self.inputController.inputBar.inputTextView.overrideNextResponder = nil;
}

- (void)messageController:(TUIBaseMessageController_Minimalist *)controller onReEditMessage:(TUIMessageCellData *)data {
    V2TIMMessage *message = data.innerMessage;
    if (message.elemType == V2TIM_ELEM_TYPE_TEXT) {
        NSString *text = message.textElem.text;
        self.inputController.inputBar.inputTextView.text = text;
        [self.inputController.inputBar.inputTextView becomeFirstResponder];
    }
}

- (CGFloat)getTopMarginByCustomView {
    return [self topMarginByCustomView];
}

- (void)messageController:(TUIBaseMessageController_Minimalist *)controller onSelectMessageWhenMultiCheckboxAppear:(TUIMessageCellData *)data {
    if (_multiChooseView) {
        NSArray *uiMsgs = [self.messageController multiSelectedResult:TUIMultiResultOptionAll];
        _multiChooseView.selectedCountLabel.text = [NSString stringWithFormat:@"%lu %@",(unsigned long)uiMsgs.count,TIMCommonLocalizableString(TUIKitSelected)];
    }
}
#pragma mark - TUIChatBaseDataProviderDelegate
- (NSString *)dataProvider:(TUIChatBaseDataProvider *)dataProvider mergeForwardTitleWithMyName:(NSString *)name {
    return [self forwardTitleWithMyName:name];
}

- (NSString *)dataProvider:(TUIChatBaseDataProvider *)dataProvider mergeForwardMsgAbstactForMessage:(V2TIMMessage *)message {
    return @"";
}

- (void)dataProvider:(TUIChatBaseDataProvider *)dataProvider sendMessage:(V2TIMMessage *)message {
    [self.messageController sendMessage:message];
}

- (void)onSelectPhotoMoreCellData {
    [self.mediaProvider selectPhoto];
}

- (void)onTakePictureMoreCellData {
    [self.mediaProvider takePicture];
}

- (void)onTakeVideoMoreCellData {
    [self.mediaProvider takeVideo];
}

- (void)onSelectFileMoreCellData {
    [self.mediaProvider selectFile];
}

#pragma mark - TUINavigationControllerDelegate
- (void)navigationControllerDidClickLeftButton:(TUINavigationController *)controller {
    if (controller.currentShowVC == self) {
        [self.messageController readReport];
    }
}

- (void)navigationControllerDidSideSlideReturn:(TUINavigationController *)controller
                            fromViewController:(UIViewController *)fromViewController {
    if ([fromViewController isEqual:self]) {
        [self.messageController readReport];
    }
}

#pragma mark - 消息菜单操作: 多选 & 转发
- (void)onSelectMessageMenu:(NSInteger)menuType withData:(TUIMessageCellData *)data {
    if (menuType == 0) {
        [self openMultiChooseBoard:YES];
    } else if (menuType == 1) {
        if (data == nil) {
            return;
        }
        NSMutableArray *uiMsgs = [NSMutableArray arrayWithArray:@[data]];
        [self prepareForwardMessages:uiMsgs];
    }
}

- (void)openMultiChooseBoard:(BOOL)open {
    [self.view endEditing:YES];
    
    if (_multiChooseView) {
        [_multiChooseView removeFromSuperview];
    }
    
    if (open) {
        _multiChooseView = [[TUIMessageMultiChooseView_Minimalist alloc] init];
        _multiChooseView.frame = UIScreen.mainScreen.bounds;
        _multiChooseView.delegate = self;
        _multiChooseView.titleLabel.text = self.conversationData.title;
        _multiChooseView.selectedCountLabel.text = [NSString stringWithFormat:@"%d %@",1,TIMCommonLocalizableString(TUIKitSelected)];
        if (@available(iOS 12.0, *)) {
            if (@available(iOS 13.0, *)) {
                // > ios 12
                [UIApplication.sharedApplication.keyWindow addSubview:_multiChooseView];
            } else {
                // ios = 12
                UIView *view = self.navigationController.view;
                if (view == nil) {
                    view = self.view;
                }
                [view addSubview:_multiChooseView];
            }
        } else {
            // < ios 12
            [UIApplication.sharedApplication.keyWindow addSubview:_multiChooseView];
        }
    } else {
        [self.messageController enableMultiSelectedMode:NO];
    }
}

- (void)messageMultiChooseViewOnCancelClicked:(TUIMessageMultiChooseView_Minimalist *)multiChooseView {
    [self openMultiChooseBoard:NO];
    [self.messageController enableMultiSelectedMode:NO];
}

- (void)messageMultiChooseViewOnRelayClicked:(TUIMessageMultiChooseView_Minimalist *)multiChooseView {
    NSArray *uiMsgs = [self.messageController multiSelectedResult:TUIMultiResultOptionAll];
    [self prepareForwardMessages:uiMsgs];
}

- (void)messageMultiChooseViewOnDeleteClicked:(TUIMessageMultiChooseView_Minimalist *)multiChooseView {
    NSArray *uiMsgs = [self.messageController multiSelectedResult:TUIMultiResultOptionAll];
    if (uiMsgs.count == 0) {
        [TUITool makeToast:TIMCommonLocalizableString(TUIKitRelayNoMessageTips)];
        return;
    }
    
    [self.messageController deleteMessages:uiMsgs];
    [self openMultiChooseBoard:NO];
    [self.messageController enableMultiSelectedMode:NO];
}

- (void)prepareForwardMessages:(NSArray<TUIMessageCellData *> *)uiMsgs {
    if (uiMsgs.count == 0) {
        [TUITool makeToast:TIMCommonLocalizableString(TUIKitRelayNoMessageTips)];
        return;
    }

    BOOL hasUnsupportMsg = NO;
    for (TUIMessageCellData *data in uiMsgs) {
        if (data.status != Msg_Status_Succ) {
            hasUnsupportMsg = YES;
            break;
        }
    }
    
    if (hasUnsupportMsg) {
        UIAlertController *vc = [UIAlertController alertControllerWithTitle:TIMCommonLocalizableString(TUIKitRelayUnsupportForward) message:nil preferredStyle:UIAlertControllerStyleAlert];
        [vc tuitheme_addAction:[UIAlertAction actionWithTitle:TIMCommonLocalizableString(Confirm) style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            
        }]];
        [self presentViewController:vc animated:YES completion:nil];
        return;
    }
    
    __weak typeof(self) weakSelf = self;
    void(^chooseTarget)(BOOL) = ^(BOOL mergeForward) {
        UIViewController * vc = (UIViewController *)[TUICore createObject:TUICore_TUIConversationObjectFactory_Minimalist key:TUICore_TUIConversationObjectFactory_GetConversationSelectControllerMethod param:nil];
        TUIFloatViewController *floatVC = [[TUIFloatViewController alloc] init];
        [floatVC appendChildViewController:(id)vc topMargin:kScale390(87.5)];
        [floatVC.topGestureView setTitleText:@"" subTitleText:@"" leftBtnText:TIMCommonLocalizableString(TUIKitCreateCancel) rightBtnText:TIMCommonLocalizableString(MultiSelect)];
        floatVC.topGestureView.subTitleLabel.hidden = YES;
        weakSelf.forwardConversationSelectVC = (UIViewController *)vc;
        weakSelf.forwardSelectUIMsgs = uiMsgs;
        weakSelf.isMergeForward = mergeForward;
        [self presentViewController:floatVC animated:YES completion:^{
            weakSelf.responseKeyboard = NO;
            [weakSelf openMultiChooseBoard:NO];
            [weakSelf.messageController enableMultiSelectedMode:NO];
        }];
    };
    
    UIAlertController *tipsVc = [UIAlertController alertControllerWithTitle:nil message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    
    /**
     * 逐条转发
     * Forward one-by-one
     */
    [tipsVc tuitheme_addAction:[UIAlertAction actionWithTitle:TIMCommonLocalizableString(TUIKitRelayOneByOneForward) style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        if (uiMsgs.count <= 30) {
            chooseTarget(NO);
            return;
        }
        UIAlertController *vc = [UIAlertController alertControllerWithTitle:TIMCommonLocalizableString(TUIKitRelayOneByOnyOverLimit) message:nil preferredStyle:UIAlertControllerStyleAlert];
        [vc tuitheme_addAction:[UIAlertAction actionWithTitle:TIMCommonLocalizableString(Cancel) style:UIAlertActionStyleDefault handler:nil]];
        [vc tuitheme_addAction:[UIAlertAction actionWithTitle:TIMCommonLocalizableString(TUIKitRelayCombineForwad) style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            chooseTarget(YES);
        }]];
        [weakSelf presentViewController:vc animated:YES completion:nil];
    }]];
    
    /**
     * 合并转发
     * Merge-forward
     */
    [tipsVc tuitheme_addAction:[UIAlertAction actionWithTitle:TIMCommonLocalizableString(TUIKitRelayCombineForwad) style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        chooseTarget(YES);
    }]];
    [tipsVc tuitheme_addAction:[UIAlertAction actionWithTitle:TIMCommonLocalizableString(Cancel) style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:tipsVc animated:YES completion:nil];
}

- (void)forwardMessages:(NSArray<TUIMessageCellData *> *)uiMsgs
              toTargets:(NSArray<TUIChatConversationModel *> *)targets
                  merge:(BOOL)merge {
    if (uiMsgs.count == 0 || targets.count == 0) {
        return ;
    }
    
    @weakify(self);
    [self.dataProvider getForwardMessageWithCellDatas:uiMsgs
                                            toTargets:targets
                                                Merge:merge
                                          ResultBlock:^(TUIChatConversationModel * _Nonnull targetConversation, NSArray<V2TIMMessage *> * _Nonnull msgs) {
        @strongify(self);
        
        TUIChatConversationModel *convCellData = targetConversation;
        NSTimeInterval timeInterval = convCellData.groupID.length?0.09:0.05;
        
        /**
         * 发送到当前聊天窗口
         * Forward to currernt chat vc
         */
        if ([convCellData.conversationID isEqualToString:self.conversationData.conversationID]) {
            for (V2TIMMessage *imMsg in msgs) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    /**
                     * 下面的函数涉及到 UI 的刷新，要放在主线程操作
                     * The following functions involve the refresh of the UI and should be called on the main thread
                     */
                    [self.messageController sendMessage:imMsg];
                });
                
                /**
                 * 此处的延时操作是为了在批量逐条转发时，尽可能保证接收端的顺序
                 * The delay here is to ensure the order of the receiving end as much as possible when forwarding in batches one by one
                 */
                [NSThread sleepForTimeInterval:timeInterval];
            }
            return;
        }
        
        /**
         * 发送到其他聊天
         * Forward to other chat user
         */
        for (V2TIMMessage *message in msgs) {
            message.needReadReceipt = [TUIChatConfig defaultConfig].msgNeedReadReceipt;
            [TUIMessageDataProvider_Minimalist sendMessage:message
                                            toConversation:convCellData
                                            isSendPushInfo:YES
                                          isOnlineUserOnly:NO
                                                  priority:V2TIM_PRIORITY_NORMAL
                                                  Progress:nil
                                                 SuccBlock:^{
                /**
                 * 发送到其他聊天的消息需要广播消息发送状态，方便进入对应聊天后刷新消息状态
                 * Messages sent to other chats need to broadcast the message sending status, which is convenient to refresh the message status after entering the corresponding chat
                 */
                [NSNotificationCenter.defaultCenter postNotificationName:TUIKitNotification_onMessageStatusChanged object:message.msgID];
            } FailBlock:^(int code, NSString *desc) {
                [NSNotificationCenter.defaultCenter postNotificationName:TUIKitNotification_onMessageStatusChanged object:message.msgID];
            }];
            
            /**
             * 此处的延时操作是为了在批量逐条转发时，尽可能保证接收端的顺序
             * The delay here is to ensure the order of the receiving end as much as possible when forwarding in batches one by one
             */
            [NSThread sleepForTimeInterval:timeInterval];
        }
    } fail:^(int code, NSString *desc) {
        NSLog(@"%@", desc);
        NSAssert(NO, desc);
    }];
}

- (NSString *)forwardTitleWithMyName:(NSString *)nameStr {
    return @"";
}

#pragma mark - Message reply
- (void)messageController:(TUIBaseMessageController_Minimalist *)controller onRelyMessage:(nonnull TUIMessageCellData *)data {
    @weakify(self)
    [self.inputController exitReplyAndReference:^{
        @strongify(self)
        NSString *desc = @"";
        desc = [self replyReferenceMessageDesc:data];
        
        TUIReplyPreviewData_Minimalist *replyData = [[TUIReplyPreviewData_Minimalist alloc] init];
        replyData.msgID = data.msgID;
        replyData.msgAbstract = desc;
        replyData.sender = data.name;
        replyData.type = (NSInteger)data.innerMessage.elemType;
        replyData.originMessage = data.innerMessage;
        
        NSMutableDictionary *cloudResultDic = [[NSMutableDictionary alloc] initWithCapacity:5];
        if (replyData.originMessage.cloudCustomData) {
            NSDictionary * originDic = [TUITool jsonData2Dictionary:replyData.originMessage.cloudCustomData];
            if (originDic && [originDic isKindOfClass:[NSDictionary class]]) {
                [cloudResultDic addEntriesFromDictionary:originDic];
            }
        }
        NSString * messageParentReply = cloudResultDic[@"messageReply"];
        NSString * messageRootID = [messageParentReply valueForKey:@"messageRootID"];
        if (!IS_NOT_EMPTY_NSSTRING(messageRootID)) {
            /**
             * 源消息没有 messageRootID， 则需要将当前源消息的 msgID 作为 root
             * If the original message does not have messageRootID, you need to make the msgID of the current original message as the root
             */
            if (IS_NOT_EMPTY_NSSTRING(replyData.originMessage.msgID)) {
                messageRootID = replyData.originMessage.msgID;
            }
        }
        
        replyData.messageRootID =  messageRootID;
        [self.inputController showReplyPreview:replyData];
    }];
    
}
- (NSString *)replyReferenceMessageDesc:(TUIMessageCellData *)data {
    NSString *desc = @"";
    if (data.innerMessage.elemType == V2TIM_ELEM_TYPE_FILE) {
        desc = data.innerMessage.fileElem.filename;
    } else if (data.innerMessage.elemType == V2TIM_ELEM_TYPE_MERGER) {
        desc = data.innerMessage.mergerElem.title;
    } else if (data.innerMessage.elemType == V2TIM_ELEM_TYPE_CUSTOM) {
        desc = [TUIMessageDataProvider_Minimalist getDisplayString:data.innerMessage];
    } else if (data.innerMessage.elemType == V2TIM_ELEM_TYPE_TEXT) {
        desc = data.innerMessage.textElem.text;
    }
    return desc;
}
#pragma mark - Message quote
- (void)messageController:(TUIBaseMessageController_Minimalist *)controller onReferenceMessage:(TUIMessageCellData *)data {
    @weakify(self)
    [self.inputController exitReplyAndReference:^{
        @strongify(self)
        NSString *desc = @"";
        desc = [self replyReferenceMessageDesc:data];
        
        TUIReferencePreviewData_Minimalist *referenceData = [[TUIReferencePreviewData_Minimalist alloc] init];
        referenceData.msgID = data.msgID;
        referenceData.msgAbstract = desc;
        referenceData.sender = data.name;
        referenceData.type = (NSInteger)data.innerMessage.elemType;
        referenceData.originMessage = data.innerMessage;
        [self.inputController showReferencePreview:referenceData];
    }];
    
}

#pragma mark - Message react
/*
 "messageReact": {
     "reacts": [
         {
             "emojiId1": ["userId1","userId2"]
         },
         {
             "emojiId2": ["userId3","userId4"]
         },
     ],
     "version": "1",
 }
 */
- (void)messageController:(TUIBaseMessageController_Minimalist *)controller modifyMessage:(nonnull TUIMessageCellData *)cellData reactEmoji:(NSString *)emojiName{
    
    V2TIMMessage *rootMsg = cellData.innerMessage;

    [[TUIChatModifyMessageHelper defaultHelper] modifyMessage:rootMsg reactEmoji:emojiName];
}

- (void)messageController:(TUIBaseMessageController_Minimalist *)controller modifyMessage:(TUIMessageCellData *)data faceList:(NSArray <TUITagsModel *>*)listModel {
    
    TUIChatMembersReactController* detailController = [[TUIChatMembersReactController alloc] initWithChatConversationModel:self.conversationData];
    detailController.modalPresentationStyle = UIModalPresentationCustom;
    detailController.tagsArray = listModel;
    detailController.originData = data;
    [self presentViewController:detailController animated:YES completion:nil];

}

#pragma mark - Translation forward
- (void)messageController:(TUIBaseMessageController_Minimalist *)controller onForwardText:(NSString *)text {
    if (text.length == 0) {
        return;
    }
    self.forwardText = text;
    [self presentConverationSelectVC];
}

- (void)presentConverationSelectVC {
    UIViewController *vc = (UIViewController *)[TUICore createObject:TUICore_TUIConversationObjectFactory_Minimalist key:TUICore_TUIConversationObjectFactory_GetConversationSelectControllerMethod param:nil];
    TUIFloatViewController *floatVC = [[TUIFloatViewController alloc] init];
    [floatVC appendChildViewController:(id)vc topMargin:kScale390(87.5)];
    [floatVC.topGestureView setTitleText:@"" subTitleText:@"" leftBtnText:TIMCommonLocalizableString(TUIKitCreateCancel) rightBtnText:TIMCommonLocalizableString(MultiSelect)];
    floatVC.topGestureView.subTitleLabel.hidden = YES;
    self.forwardConversationSelectVC = (UIViewController *)vc;
    [self presentViewController:floatVC animated:YES completion:nil];
}

- (void)forwardText:(NSString *)text toConverations:(NSArray <TUIChatConversationModel *> *)conversations {
    for (TUIChatConversationModel *conversation in conversations) {
        V2TIMMessage *message = [[V2TIMManager sharedInstance] createTextMessage:text];
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([conversation.conversationID isEqualToString:self.conversationData.conversationID]) {
                // Send text to myself
                [self.messageController sendMessage:message];
            } else {
                // Send to other conversation
                message.needReadReceipt = [TUIChatConfig defaultConfig].msgNeedReadReceipt;
                [TUIMessageBaseDataProvider sendMessage:message
                                     toConversation:conversation
                                     isSendPushInfo:YES
                                   isOnlineUserOnly:NO
                                           priority:V2TIM_PRIORITY_NORMAL
                                           Progress:nil
                                          SuccBlock:^{
                    [NSNotificationCenter.defaultCenter postNotificationName:TUIKitNotification_onMessageStatusChanged
                                                                      object:message.msgID];
                } FailBlock:^(int code, NSString *desc) {
                    [NSNotificationCenter.defaultCenter postNotificationName:TUIKitNotification_onMessageStatusChanged
                                                                      object:message.msgID];
                }];
            }
        });
    }
}

#pragma mark - Private Methods
+ (void)createCachePath {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if(![fileManager fileExistsAtPath:TUIKit_Image_Path]){
        [fileManager createDirectoryAtPath:TUIKit_Image_Path withIntermediateDirectories:YES attributes:nil error:nil];
    }
    if(![fileManager fileExistsAtPath:TUIKit_Video_Path]){
        [fileManager createDirectoryAtPath:TUIKit_Video_Path withIntermediateDirectories:YES attributes:nil error:nil];
    }
    if(![fileManager fileExistsAtPath:TUIKit_Voice_Path]){
        [fileManager createDirectoryAtPath:TUIKit_Voice_Path withIntermediateDirectories:YES attributes:nil error:nil];
    }
    if(![fileManager fileExistsAtPath:TUIKit_File_Path]){
        [fileManager createDirectoryAtPath:TUIKit_File_Path withIntermediateDirectories:YES attributes:nil error:nil];
    }
    if(![fileManager fileExistsAtPath:TUIKit_DB_Path]){
        [fileManager createDirectoryAtPath:TUIKit_DB_Path withIntermediateDirectories:YES attributes:nil error:nil];
    }
}

#pragma mark - TUIJoinGroupMessageCellDelegate
- (void)didTapOnRestNameLabel:(TUIJoinGroupMessageCell_Minimalist *)cell withIndex:(NSInteger)index{
    NSString *userId = cell.joinData.userIDList[index];
    
    [self getUserOrFriendProfileVCWithUserID:userId succBlock:^(UIViewController *vc) {
        [self.navigationController pushViewController:vc animated:YES];
    } failBlock:^(int code, NSString *desc) {
        [TUITool makeToastError:code msg:desc];
    }];
}

#pragma mark - V2TIMConversationListener
- (void)onConversationChanged:(NSArray<V2TIMConversation*> *) conversationList {
    for (V2TIMConversation *conv in conversationList) {
        if ([conv.conversationID isEqualToString:self.conversationData.conversationID]) {
            if (!self.conversationData.otherSideTyping) {
                self.conversationData.title = conv.showName;
            }
            break;
        }
    }
}

#pragma mark - FriendInfoChangedNotification
- (void)onFriendInfoChanged:(NSNotification *)notice {
    [self checkTitle:YES];
}

#pragma mark - Media Provider
- (TUIChatMediaDataProvider *)mediaProvider {
    if (_mediaProvider == nil) {
        _mediaProvider = [[TUIChatMediaDataProvider alloc] init];
        _mediaProvider.listener = self;
        _mediaProvider.presentViewController = self;
    }
    return _mediaProvider;
}

- (void)onProvideImage:(NSString *)imageUrl {
    V2TIMMessage *message = [V2TIMManager.sharedInstance createImageMessage:imageUrl];
    [self sendMessage:message];
}

- (void)onProvideImageError:(NSString *)errorMessage {
    [TUITool makeToast:errorMessage];
}

- (void)onProvideVideo:(NSString *)videoUrl snapshot:(NSString *)snapshotUrl duration:(NSInteger)duration {
    V2TIMMessage *message = [V2TIMManager.sharedInstance createVideoMessage:videoUrl type:videoUrl.pathExtension duration:(int)duration snapshotPath:snapshotUrl];
    [self sendMessage:message];
}

- (void)onProvideVideoError:(NSString *)errorMessage {
    [TUITool makeToast:errorMessage];
}

- (void)onProvideFile:(NSString *)fileUrl filename:(NSString *)filename fileSize:(NSInteger)fileSize {
    V2TIMMessage *message = [V2TIMManager.sharedInstance createFileMessage:fileUrl fileName:filename];
    [self sendMessage:message];
}

- (void)onProvideFileError:(NSString *)errorMessage {
    [TUITool makeToast:errorMessage];
}

@end
