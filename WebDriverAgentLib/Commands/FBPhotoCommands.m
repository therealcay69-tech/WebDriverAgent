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
      [FBCommandStatus invalidArgumentErrorWithMessage:@"Missing filePath"
                                         traceback:nil]
    );
  }

  if (![[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
    return FBResponseWithStatus(
      [FBCommandStatus invalidArgumentErrorWithMessage:
        [NSString stringWithFormat:@"File does not exist: %@", filePath]
                                         traceback:nil]
    );
  }

  NSURL *fileURL = [NSURL fileURLWithPath:filePath];

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

  return FBResponseWithObject(@{
    @"localIdentifier": placeholder.localIdentifier ?: @""
  });
}

@end
