#import "FBPhotoCommands.h"

#import <Photos/Photos.h>

#import "FBCommandStatus.h"
#import "FBResponsePayload.h"
#import "FBRoute.h"
#import "FBRouteRequest.h"

@implementation FBPhotoCommands

+ (NSArray *)routes
{
  return @[
    [[FBRoute POST:@"/wda/addFileToPhotos"].withoutSession
      respondWithTarget:self
      action:@selector(handleAddFileToPhotos:)]
  ];
}

+ (id<FBResponsePayload>)handleAddFileToPhotos:(FBRouteRequest *)request
{
  NSString *filePath = request.arguments[@"filePath"];

  if (![filePath isKindOfClass:[NSString class]] || filePath.length == 0) {
    return FBResponseWithStatus(
      [FBCommandStatus invalidArgumentWithMessage:@"Missing filePath"
                                         traceback:nil]
    );
  }

  if (![[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
    return FBResponseWithStatus(
      [FBCommandStatus invalidArgumentWithMessage:
        [NSString stringWithFormat:@"File does not exist: %@", filePath]
                                         traceback:nil]
    );
  }

  NSURL *fileURL = [NSURL fileURLWithPath:filePath];

  PHAuthorizationStatus status =
    [PHPhotoLibrary authorizationStatusForAccessLevel:PHAccessLevelAddOnly];

  if (status == PHAuthorizationStatusNotDetermined) {
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);

    [[PHPhotoLibrary sharedPhotoLibrary]
      requestAuthorizationForAccessLevel:PHAccessLevelAddOnly
      handler:^(PHAuthorizationStatus newStatus) {
        status = newStatus;
        dispatch_semaphore_signal(semaphore);
      }];

    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
  }

  if (status != PHAuthorizationStatusAuthorized &&
      status != PHAuthorizationStatusLimited) {
    return FBResponseWithStatus(
      [FBCommandStatus unknownErrorWithMessage:
        @"Photos access was not authorized"
                                         traceback:nil]
    );
  }

  __block PHObjectPlaceholder *placeholder = nil;
  __block NSError *changeError = nil;

  BOOL success = [[PHPhotoLibrary sharedPhotoLibrary]
    performChangesAndWait:^{
      PHAssetChangeRequest *changeRequest =
        [PHAssetChangeRequest creationRequestForAssetFromVideoAtFileURL:fileURL];

      placeholder = changeRequest.placeholderForCreatedAsset;
    }
    error:&changeError];

  if (!success || changeError != nil || placeholder == nil) {
    NSString *message =
      changeError != nil
        ? changeError.localizedDescription
        : @"Failed to create video asset in Photos";

    return FBResponseWithStatus(
      [FBCommandStatus unknownErrorWithMessage:message
                                       traceback:nil]
    );
  }

  return FBResponseWithValue(@{
    @"localIdentifier": placeholder.localIdentifier ?: @""
  });
}

@end
