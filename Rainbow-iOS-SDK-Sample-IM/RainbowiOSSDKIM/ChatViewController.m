/*
 * Rainbow SDK sample
 *
 * Copyright (c) 2018, ALE International
 * All rights reserved.
 *
 * ALE International Proprietary Information
 *
 * Contains proprietary/trade secret information which is the property of
 * ALE International and must not be made available to, or copied or used by
 * anyone outside ALE International without its written authorization
 *
 * Not to be disclosed or used except in accordance with applicable agreements.
 */

#import "ChatViewController.h"
#import <Rainbow/Rainbow.h>
#import "MyUserTableViewCell.h"
#import "PeerTableViewCell.h"

#define kPageSize 50

@interface MessageItem : NSObject
@property (strong, nonatomic) Contact *contact;
@property (strong, nonatomic) NSString *text;
@end

@implementation MessageItem
@end

@interface ChatViewController ()
@property (weak, nonatomic) IBOutlet UITableView *messageList;
@property (weak, nonatomic) IBOutlet UITextView *textInput;
@property (weak, nonatomic) IBOutlet UIButton *sendButton;

@property (strong, nonatomic) ServicesManager *serviceManager;
@property (strong, nonatomic) ConversationsManagerService *conversationsManager;
@property (strong, nonatomic) MessagesBrowser *messagesBrowser;
@property (strong, nonatomic) NSMutableArray<MessageItem *> *messages;
@property (strong, nonatomic) UIImage *myAvatar;
@property (strong, nonatomic) UIImage *peerAvatar;
@property (strong, nonatomic) Conversation *theConversation;
@end

@implementation ChatViewController

-(instancetype) initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if(self){
        _serviceManager = [ServicesManager sharedInstance];
        _conversationsManager = [ServicesManager sharedInstance].conversationsManagerService;
        if(_serviceManager.myUser.contact.photoData){
            _myAvatar = [UIImage imageWithData: _serviceManager.myUser.contact.photoData];
        } else {
            _myAvatar = nil;
        }
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.textInput.delegate = self;
    self.messages = [[NSMutableArray alloc] init];
    if(self.contact.photoData){
        self.peerAvatar = [UIImage imageWithData: self.contact.photoData];
    } else {
        self.peerAvatar = nil;
    }
    
    // All conversations for myUser
    NSArray<Conversation *> *conversationsArray = self.conversationsManager.conversations;
    self.theConversation = nil;
    
    for(Conversation *conversation in conversationsArray){
        if(conversation.peer == (Peer *)self.contact){
            self.theConversation = conversation;
            break;
        }
    }
    // If there is no conversation with this peer, create a new one
    if(!self.theConversation){
        [[ServicesManager sharedInstance].conversationsManagerService startConversationWithPeer:self.contact withCompletionHandler:^(Conversation *conversation, NSError *error) {
            if(!error){
                self.theConversation = conversation;
            } else {
                NSLog(@"Can't create the new conversation, error: %@", [error description]);
            }
        }];
    }
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:@"UIKeyboardWillShowNotification" object: nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardDidHide:) name:@"UIKeyboardDidHideNotification" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didReceiveNewMessage:) name:kConversationsManagerDidReceiveNewMessageForConversation object:nil];
    
    self.messagesBrowser = [self.conversationsManager messagesBrowserForConversation:self.theConversation withPageSize:kPageSize preloadMessages:YES];
    self.messagesBrowser.delegate = self;
    [_messagesBrowser resyncBrowsingCacheWithCompletionHandler:^(NSArray *addedCacheItems, NSArray *removedCacheItems, NSArray *updatedCacheItems, NSError *error) {
        NSLog(@"Resync done");
    }];
}

-(void)dealloc {
     [_messagesBrowser reset];
    _messagesBrowser.delegate = nil;
    _messagesBrowser = nil;
    _messages = nil;
    _myAvatar = nil;
    _peerAvatar = nil;
    _serviceManager = nil;
    _conversationsManager = nil;
}

#pragma mark - IBAction

- (IBAction)sendAction:(id)sender {
    if(self.theConversation){
        self.sendButton.enabled = NO;
        self.textInput.editable = NO;
        [self.conversationsManager sendMessage:self.textInput.text fileAttachment:nil to:self.theConversation completionHandler:^(Message *message, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if(!error){
                    self.textInput.text = @"";
                } else {
                    NSLog(@"Can't send message to the conversation error: %@",[error description]);
                    self.sendButton.enabled = YES;
                }
                self.textInput.editable = YES;
            });
        } attachmentUploadProgressHandler:nil];
    }
}

#pragma mark - Browsing delegate

-(void) itemsBrowser:(CKItemsBrowser*)browser didAddCacheItems:(NSArray*)newItems atIndexes:(NSIndexSet*)indexes {
    if(![NSThread isMainThread]){
        dispatch_async(dispatch_get_main_queue(), ^{
            [self itemsBrowser:browser didAddCacheItems:newItems atIndexes:indexes];
        });
        return;
    }
    NSLog(@"%@ %@", NSStringFromSelector(_cmd), newItems);
    @synchronized(self.messages){
        for(Message *message in [newItems reverseObjectEnumerator]){
            MessageItem *item = [[MessageItem alloc] init];
            if(message.isOutgoing){
                item.contact = _serviceManager.myUser.contact;
            } else {
                item.contact = (Contact *)message.peer;
            }
            item.text = message.body;
            [self.messages addObject:item];
        }
        [self.messageList reloadData];
    }
}

-(void) itemsBrowser:(CKItemsBrowser*)browser didRemoveCacheItems:(NSArray*)removedItems atIndexes:(NSIndexSet*)indexes {
    if(browser != self.messagesBrowser){
        return;
    }
    
    if(![NSThread isMainThread]){
        dispatch_async(dispatch_get_main_queue(), ^{
            [self itemsBrowser:browser didRemoveCacheItems:removedItems atIndexes:indexes];
        });
        return;
    }
    
    NSLog(@"%@ %@", NSStringFromSelector(_cmd), removedItems);
}

-(void) itemsBrowser:(CKItemsBrowser*)browser didUpdateCacheItems:(NSArray*)changedItems atIndexes:(NSIndexSet*)indexes {
    if(![NSThread isMainThread]){
        dispatch_async(dispatch_get_main_queue(), ^{
            [self itemsBrowser:browser didUpdateCacheItems:changedItems atIndexes:indexes];
        });
        return;
    }
    
    NSLog(@"%@ %@", NSStringFromSelector(_cmd), changedItems);
}

-(void) itemsBrowser:(CKItemsBrowser*)browser didReorderCacheItemsAtIndexes:(NSArray*)oldIndexes toIndexes:(NSArray*)newIndexes {
    if(![NSThread isMainThread]){
        dispatch_async(dispatch_get_main_queue(), ^{
            [self itemsBrowser:browser didReorderCacheItemsAtIndexes:oldIndexes toIndexes:newIndexes];
        });
        return;
    }
    
    NSLog(@"%@", NSStringFromSelector(_cmd));
}

-(void) itemsBrowser:(CKItemsBrowser *)browser didReceiveItemsAddedEvent:(NSArray *)addedItems {
    if(![NSThread isMainThread]){
        dispatch_async(dispatch_get_main_queue(), ^{
            [self itemsBrowser:browser didReceiveItemsAddedEvent:addedItems];
        });
        return;
    }
    
     NSLog(@"%@", NSStringFromSelector(_cmd));
}

#pragma mark - UITextviewDelegate

- (void)textViewDidChange:(UITextView *)textView {
    self.sendButton.enabled = textView.text.length > 0 ? YES : NO;
}

#pragma mark - Conversation manager notification

- (void) didReceiveNewMessage : (NSNotification *) notification {
    Conversation * receivedConversation  = notification.object;
    if(receivedConversation == self.theConversation){
        NSLog(@"did received new message for the conversation");
    }
}

#pragma mark - Keyboard notification

- (void)keyboardWillShow:(NSNotification *)notification{
    if(![NSThread isMainThread]){
        dispatch_async(dispatch_get_main_queue(), ^{
            [self keyboardWillShow:notification];
        });
        return;
    }
    [UIView beginAnimations:nil context:nil];
    NSDictionary *userInfo = notification.userInfo;
    NSValue *keyboardFrame = [userInfo valueForKey: UIKeyboardFrameEndUserInfoKey];
    CGRect keyboardRectangle = [keyboardFrame CGRectValue];
    self.view.frame = CGRectMake(0,  - keyboardRectangle.size.height, self.view.frame.size.width, self.view.frame.size.height);
    [UIView commitAnimations];
}

- (void)keyboardDidHide:(NSNotification *)notification{
    if(![NSThread isMainThread]){
        dispatch_async(dispatch_get_main_queue(), ^{
            [self keyboardDidHide:notification];
        });
        return;
    }
    [UIView beginAnimations:nil context:nil];
    self.view.frame = CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height);
    [UIView commitAnimations];
}

#pragma mark - UITableViewDataSource

-(NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.messages.count;
}

-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
    NSInteger row = indexPath.row;
    
    if (self.messages[row].contact == _serviceManager.myUser.contact){
        return [tableView dequeueReusableCellWithIdentifier:@"MyUserTableViewCell" forIndexPath:indexPath];
    } else {
        return [tableView dequeueReusableCellWithIdentifier:@"PeerTableViewCell" forIndexPath:indexPath];
    }
}

#pragma mark - UITableViewDelegate

-(void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    NSInteger row = indexPath.row;
    if([cell isKindOfClass:[MyUserTableViewCell class]]){
        MyUserTableViewCell  *myCell = (MyUserTableViewCell *)cell;
        if(self.myAvatar){
            myCell.avatar.image = self.myAvatar;
            myCell.message.text = self.messages[row].text;
        }
    } else {
        PeerTableViewCell *peerCell = (PeerTableViewCell *)cell;
        if(self.peerAvatar){
            peerCell.avatar.image = self.peerAvatar;
            peerCell.message.text = self.messages[row].text;
        }
    }
}

@end
