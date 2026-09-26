// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'PAO';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get submit => 'Submit';

  @override
  String get apply => 'Apply';

  @override
  String get reset => 'Reset';

  @override
  String get continueLabel => 'Continue';

  @override
  String get paoUser => 'PAO User';

  @override
  String get paoItem => 'PAO item';

  @override
  String get yourName => 'Your Name';

  @override
  String get somethingWentWrong => 'Something went wrong. Please try again.';

  @override
  String get failedToUpdate => 'Failed to update. Please try again.';

  @override
  String get noInternet =>
      'No internet connection. Please check your network and try again.';

  @override
  String get errorInvalidCredentials => 'Incorrect email or password.';

  @override
  String get errorUserAlreadyExists =>
      'An account with this email already exists.';

  @override
  String get errorEmailNotConfirmed =>
      'Please confirm your email before logging in.';

  @override
  String get errorWeakPassword => 'Please choose a stronger password.';

  @override
  String get errorSamePassword =>
      'Your new password must be different from your old one.';

  @override
  String get errorRateLimited =>
      'Too many attempts. Please wait a moment and try again.';

  @override
  String get errorAccountBanned =>
      'Your account has been suspended. Contact support if you think this is a mistake.';

  @override
  String get welcomeBack => 'Welcome Back';

  @override
  String get loginToContinue => 'Login to continue';

  @override
  String get email => 'Email';

  @override
  String get enterYourEmail => 'Enter your email';

  @override
  String get emailRequired => 'Email is required';

  @override
  String get enterValidEmail => 'Enter a valid email';

  @override
  String get emailCannotBeChanged => 'Your email can\'t be changed';

  @override
  String get password => 'Password';

  @override
  String get enterYourPassword => 'Enter your password';

  @override
  String get passwordRequired => 'Password is required';

  @override
  String get passwordMinLength => 'Minimum 6 characters';

  @override
  String get forgotPasswordQuestion => 'Forgot Password?';

  @override
  String get login => 'Login';

  @override
  String get noAccountPrompt => 'Don\'t have an account? ';

  @override
  String get signUp => 'Sign Up';

  @override
  String get acceptTermsToContinue =>
      'Please accept the Terms & Conditions and Privacy Policy to continue.';

  @override
  String get createAccount => 'Create Account';

  @override
  String get signUpToGetStarted => 'Sign up to get started';

  @override
  String get fullName => 'Full Name';

  @override
  String get enterFullName => 'Enter your full name';

  @override
  String get nameRequired => 'Name is required';

  @override
  String get createPasswordHint => 'Create a password';

  @override
  String get confirmPassword => 'Confirm Password';

  @override
  String get reenterPassword => 'Re-enter your password';

  @override
  String get passwordsDoNotMatch => 'Passwords do not match';

  @override
  String get checkEmailToConfirm =>
      'Check your email to confirm your account, then log in.';

  @override
  String get haveAccountPrompt => 'Already have an account? ';

  @override
  String get forgotPasswordInstructions =>
      'Enter your email and we\'ll send you a link to reset your password.';

  @override
  String get resetLinkSent => 'Reset link sent! Check your inbox.';

  @override
  String get sendResetLink => 'Send Reset Link';

  @override
  String get resetPasswordTitle => 'Reset Password';

  @override
  String get resetPasswordSubtitle => 'Choose a new password for your account.';

  @override
  String get newPassword => 'New Password';

  @override
  String get enterNewPassword => 'Enter a new password';

  @override
  String get updatePassword => 'Update Password';

  @override
  String get passwordUpdated => 'Password updated';

  @override
  String get backToLogin => 'Back to Login';

  @override
  String get termsAgreePrefix => 'I agree to the ';

  @override
  String get termsAnd => ' and ';

  @override
  String get termsAgreeSuffix => '';

  @override
  String get termsAndConditions => 'Terms & Conditions';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get navHome => 'Home';

  @override
  String get navWishlist => 'Wishlist';

  @override
  String requestWantsItem(String name) {
    return '$name wants this item';
  }

  @override
  String get requestYouAsked => 'You asked for this item';

  @override
  String get navChats => 'Chats';

  @override
  String get noChatsYet => 'No chats yet';

  @override
  String get emptyChatsMessage =>
      'Tap \"Give Me\" on a product to start a chat with its owner';

  @override
  String get rejectRequest => 'Reject';

  @override
  String get rejectRequestTitle => 'Reject this request?';

  @override
  String rejectRequestConfirm(String name) {
    return '\"$name\" will not be given to this person.';
  }

  @override
  String get requestRejected => 'Request rejected';

  @override
  String get navDonors => 'Donors';

  @override
  String get donorsTitle => 'Top Donors';

  @override
  String get donorsEmpty => 'No donations yet';

  @override
  String get donorsEmptyHint => 'People who give items away will show up here.';

  @override
  String donationCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count donations',
      one: '1 donation',
    );
    return '$_temp0';
  }

  @override
  String get navRequests => 'Requests';

  @override
  String get navSettings => 'Settings';

  @override
  String get welcomeBackGreeting => 'Welcome back 👋';

  @override
  String get searchHint => 'Search...';

  @override
  String get noProductsFound => 'No products found';

  @override
  String get tryDifferentSearch =>
      'Try a different search term or clear your filters';

  @override
  String get clearSearch => 'Clear search';

  @override
  String get categoryAll => 'All';

  @override
  String get categoryElectronics => 'Electronics';

  @override
  String get categoryFashion => 'Fashion';

  @override
  String get categoryHomeLiving => 'Home & Living';

  @override
  String get categoryBeauty => 'Beauty';

  @override
  String get categorySports => 'Sports';

  @override
  String get categoryBooks => 'Books';

  @override
  String get categoryToys => 'Toys';

  @override
  String get categoryOther => 'Other';

  @override
  String get conditionNew => 'New';

  @override
  String get conditionUsed => 'Used';

  @override
  String get conditionOld => 'Old';

  @override
  String get sortNewest => 'Newest';

  @override
  String get filters => 'Filters';

  @override
  String get category => 'Category';

  @override
  String get sortBy => 'Sort By';

  @override
  String get condition => 'Condition';

  @override
  String shareProduct(String name) {
    return 'Check out \"$name\" on PAO!';
  }

  @override
  String requestedProduct(String name) {
    return 'Requested \"$name\" — chat with the owner anytime';
  }

  @override
  String get failedToSendRequest => 'Failed to send request. Please try again.';

  @override
  String get cantRequestOwnItem => 'You can\'t request your own item.';

  @override
  String get markAsGiven => 'Mark as Given';

  @override
  String markAsGivenConfirm(String name) {
    return 'Have you given \"$name\" to someone? It will be removed from the listing.';
  }

  @override
  String get yesGiven => 'Yes, Given';

  @override
  String get messageOwner => 'Message Owner';

  @override
  String get giveMe => 'Give Me';

  @override
  String get postedBy => 'Posted by';

  @override
  String get postedOn => 'Posted on';

  @override
  String get description => 'Description';

  @override
  String get noDescription => 'No description available for this product.';

  @override
  String get addProduct => 'Add Product';

  @override
  String get giveSomethingAway => 'Give something away for free';

  @override
  String get addItemSubtitle =>
      'Books, electronics, or anything else someone could use';

  @override
  String get photos => 'Photos';

  @override
  String get title => 'Title';

  @override
  String get titleHint => 'e.g. Wireless Headphones';

  @override
  String get titleRequired => 'Title is required';

  @override
  String get describeItemHint => 'Describe the item and its condition';

  @override
  String get descriptionRequired => 'Description is required';

  @override
  String get postForFree => 'Post for Free';

  @override
  String get addPhoto => 'Add Photo';

  @override
  String get camera => 'Camera';

  @override
  String get gallery => 'Gallery';

  @override
  String get pleaseSelectCategory => 'Please select a category';

  @override
  String get failedToPostItem => 'Failed to post item.';

  @override
  String get productPosted => 'Product posted for free giveaway';

  @override
  String get mustBeLoggedInToPost => 'You must be logged in to post an item.';

  @override
  String get requests => 'Requests';

  @override
  String get tabSent => 'Sent';

  @override
  String get tabReceived => 'Received';

  @override
  String get emptySentMessage => 'Tap \"Give Me\" on a product to request it';

  @override
  String get emptyReceivedMessage =>
      'Requests for the items you post will show up here';

  @override
  String get statusGivenToYou => 'Given to you';

  @override
  String get statusNotSelected => 'Not selected';

  @override
  String get statusDeclined => 'Declined';

  @override
  String get statusPending => 'Pending';

  @override
  String requestTo(String name) {
    return 'to $name';
  }

  @override
  String requestFrom(String name) {
    return 'from $name';
  }

  @override
  String get acceptAndGive => 'Accept & Give';

  @override
  String get leaveFeedback => 'Leave Feedback';

  @override
  String get noRequestsYet => 'No requests yet';

  @override
  String get giveThisItem => 'Give this item';

  @override
  String giveThisItemConfirm(String name) {
    return 'Give \"$name\" to this person? Other requests for it will be closed.';
  }

  @override
  String get yesGive => 'Yes, Give';

  @override
  String get itemMarkedAsGiven => 'Item marked as given';

  @override
  String get thanksForFeedback => 'Thanks for your feedback!';

  @override
  String get acceptAndGiveThisItem => 'Accept & Give This Item';

  @override
  String get receivedLeaveFeedback => 'You received this — Leave Feedback';

  @override
  String get sayHello => 'Say hello 👋';

  @override
  String get typeMessageHint => 'Type a message...';

  @override
  String get deleteMessage => 'Delete message';

  @override
  String get reply => 'Reply';

  @override
  String get you => 'You';

  @override
  String get originalMessageUnavailable => 'Original message unavailable';

  @override
  String get deleteForMe => 'Delete for me';

  @override
  String get deleteForEveryone => 'Delete for everyone';

  @override
  String get deleteForMeConfirm =>
      'Delete this message for you only? The other person will still see it.';

  @override
  String get deleteMessageConfirm =>
      'Delete this message? This cannot be undone.';

  @override
  String get failedToDeleteMessage =>
      'Failed to delete message. Please try again.';

  @override
  String get failedToLoadMessages => 'Failed to load messages.';

  @override
  String get failedToSendMessage => 'Failed to send message.';

  @override
  String get editMessage => 'Edit message';

  @override
  String get failedToEditMessage => 'Failed to edit message. Please try again.';

  @override
  String get editedLabel => '(edited)';

  @override
  String get online => 'Online';

  @override
  String lastSeenToday(String time) {
    return 'last seen today at $time';
  }

  @override
  String lastSeenYesterday(String time) {
    return 'last seen yesterday at $time';
  }

  @override
  String lastSeenOn(String date, String time) {
    return 'last seen $date at $time';
  }

  @override
  String get today => 'Today';

  @override
  String get yesterday => 'Yesterday';

  @override
  String get profile => 'Profile';

  @override
  String get tabPosts => 'Posts';

  @override
  String get tabGivenAway => 'Given Away';

  @override
  String get noPostsYet => 'No posts yet.';

  @override
  String get nothingGivenAwayYet => 'Nothing given away yet.';

  @override
  String get donated => 'Donated';

  @override
  String get noRatings => 'No ratings';

  @override
  String reviewCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count reviews',
      one: '1 review',
    );
    return '$_temp0';
  }

  @override
  String get feedback => 'Feedback';

  @override
  String get noFeedbackYet => 'No feedback yet.';

  @override
  String timeMonthsAgo(int count) {
    return '${count}mo ago';
  }

  @override
  String timeDaysAgo(int count) {
    return '${count}d ago';
  }

  @override
  String timeHoursAgo(int count) {
    return '${count}h ago';
  }

  @override
  String timeMinutesAgo(int count) {
    return '${count}m ago';
  }

  @override
  String get timeJustNow => 'Just now';

  @override
  String get pleaseSelectRating => 'Please select a rating';

  @override
  String get failedToSubmitFeedback =>
      'Failed to submit feedback. Please try again.';

  @override
  String get rateThisExchange => 'Rate this exchange';

  @override
  String get leaveCommentHint => 'Leave a comment (optional)';

  @override
  String get wishlist => 'Wishlist';

  @override
  String get wishlistEmpty => 'Your wishlist is empty';

  @override
  String get wishlistEmptyHint => 'Tap the Add button to save something';

  @override
  String get selectYourLocation => 'Select Your Location';

  @override
  String get addAddressToFinish =>
      'Add your address to finish setting up your account';

  @override
  String get country => 'Country';

  @override
  String get countryPakistan => 'Pakistan';

  @override
  String get province => 'Province';

  @override
  String get selectProvinceHint => 'Select your province';

  @override
  String get provinceRequired => 'Province is required';

  @override
  String get city => 'City';

  @override
  String get selectCityHint => 'Select your city';

  @override
  String get cityRequired => 'City is required';

  @override
  String get address => 'Address';

  @override
  String get enterAddressHint => 'Enter your address';

  @override
  String get addressRequired => 'Address is required';

  @override
  String get settings => 'Settings';

  @override
  String get sectionGeneral => 'General';

  @override
  String get sectionLegal => 'Legal';

  @override
  String get sectionSupport => 'Support';

  @override
  String get editProfile => 'Edit Profile';

  @override
  String get language => 'Language';

  @override
  String get theme => 'Theme';

  @override
  String get notifications => 'Notifications';

  @override
  String get tourSkip => 'Skip';

  @override
  String get tourNext => 'Next';

  @override
  String get tourDone => 'Got it';

  @override
  String get appTour => 'App tour';

  @override
  String get tourSearchTitle => 'Search';

  @override
  String get tourSearchBody =>
      'Type here to find items people are giving away.';

  @override
  String get tourFilterTitle => 'Filters';

  @override
  String get tourFilterBody =>
      'Narrow the list by category, condition, location and sort order.';

  @override
  String get tourWishlistTitle => 'Wishlist';

  @override
  String get tourWishlistBody =>
      'Items you tapped the heart on are saved here so you can find them later.';

  @override
  String get tourAddTitle => 'Give something away';

  @override
  String get tourAddBody =>
      'Tap here to post an item with photos, a description and your location.';

  @override
  String get tourRequestsTitle => 'Requests & chats';

  @override
  String get tourRequestsBody =>
      'Requests you sent and received live here. Open one to chat with the other person.';

  @override
  String get tourSettingsTitle => 'Settings';

  @override
  String get tourSettingsBody =>
      'Edit your profile, change language or theme, and manage notifications.';

  @override
  String get tourRequestsTabsTitle => 'Sent and Received';

  @override
  String get tourRequestsTabsBody =>
      'Sent shows items you asked for. Received shows people asking for your items, where you can accept or decline.';

  @override
  String get tourReplayTitle => 'Replay this tour';

  @override
  String get tourReplayBody => 'Tap here any time to see the app tour again.';

  @override
  String get helpCenter => 'Help Center';

  @override
  String get about => 'About';

  @override
  String get logout => 'Logout';

  @override
  String get deleteAccount => 'Delete Account';

  @override
  String get deleteAccountConfirm =>
      'This will permanently delete your account and all your data. This action cannot be undone.';

  @override
  String get failedToDeleteAccount =>
      'Failed to delete account. Please try again.';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get themeSystem => 'System Default';

  @override
  String get themeLightSubtitle => 'Bright background, dark text';

  @override
  String get themeDarkSubtitle => 'Dark background, light text';

  @override
  String get themeSystemSubtitle => 'Matches your device setting';

  @override
  String get chooseHowPaoLooks => 'Choose how PAO looks';

  @override
  String get searchLanguage => 'Search language';

  @override
  String get noLanguagesFound => 'No languages found';

  @override
  String languageSetTo(String name) {
    return 'Language set to $name';
  }

  @override
  String get failedToUpdateProfile => 'Failed to update profile.';

  @override
  String get profileUpdatedConfirmEmail =>
      'Profile updated. Check your new email to confirm the change.';

  @override
  String get profileUpdated => 'Profile updated';

  @override
  String get phoneOptional => 'Phone (optional)';

  @override
  String get enterPhoneHint => 'Enter your phone number';

  @override
  String get bioOptional => 'Bio (optional)';

  @override
  String get bioHint => 'Tell us a little about yourself';

  @override
  String get saveChanges => 'Save Changes';

  @override
  String get mustBeLoggedInPhoto =>
      'You must be logged in to update your photo.';

  @override
  String get failedToUpdatePhoto => 'Failed to update photo. Please try again.';

  @override
  String get mustBeLoggedInProfile =>
      'You must be logged in to update your profile.';

  @override
  String get frequentlyAskedQuestions => 'Frequently asked questions';

  @override
  String get stillNeedHelp => 'Still need help?';

  @override
  String get cantFindWhatYouNeed =>
      'Can\'t find what you\'re looking for? More ways to reach us will show up here soon.';

  @override
  String get faq1Q => 'How do I give away an item?';

  @override
  String get faq1A =>
      'Tap the purple + button on the home screen, add a few photos, a title, description, category and condition, then post it. It will show up in listings right away.';

  @override
  String get faq2Q => 'How do I request an item?';

  @override
  String get faq2A =>
      'Open any listing and tap \"Give Me\". This sends a request to the owner and lets you chat with them about it.';

  @override
  String get faq3Q => 'How do I chat with the owner or requester?';

  @override
  String get faq3A =>
      'Once a request has been sent, open it from the Inbox or tap \"Message Owner\" on the listing to start chatting.';

  @override
  String get faq4Q => 'How do I accept a request for my item?';

  @override
  String get faq4A =>
      'Open the chat for that request and tap \"Accept & Give This Item\". This marks the item as given and closes any other pending requests on it.';

  @override
  String get faq5Q => 'How do I save an item to my Wishlist?';

  @override
  String get faq5A =>
      'Tap the heart icon on any listing. You can find everything you\'ve saved under Settings > Wishlist.';

  @override
  String get faq6Q => 'Can I change the app language or theme?';

  @override
  String get faq6A =>
      'Yes — go to Settings and open Language or Theme to switch between English and Urdu, or between light, dark, or your device\'s default.';

  @override
  String get faq7Q => 'How do I edit my profile?';

  @override
  String get faq7A =>
      'Go to Settings > Edit Profile to update your name, photo, and other details.';

  @override
  String get faq8Q => 'How do I delete my account?';

  @override
  String get faq8A =>
      'Go to Settings > Delete Account. This permanently removes your profile and data and cannot be undone.';

  @override
  String get faq9Q => 'Is my data safe?';

  @override
  String get faq9A =>
      'We only use your information to run the app\'s features. See our Privacy Policy under Settings > Legal for the full details.';

  @override
  String legalLastUpdated(String date) {
    return 'Last updated: $date';
  }

  @override
  String get legalDate => 'September 18, 2026';

  @override
  String get privacyDate => 'September 26, 2026';

  @override
  String get privacy1Title => '1. Information We Collect';

  @override
  String get privacy1Body =>
      'We collect information you provide directly, such as your name, email address, profile photo, and the listings, requests, or messages you create. This includes photos, videos, and voice messages you choose to send in chat, which are accessed through your camera, photo library, or microphone only when you use those features. We also collect information generated by using the app, such as your wishlist, saved location/province, and app preferences (theme, language). If you report or block another user, we also collect that report (the reason you choose, any details you add, who it is about and when) and the block itself.';

  @override
  String get privacy2Title => '2. How We Use Your Information';

  @override
  String get privacy2Body =>
      'We use your information to operate the app\'s core features: showing your profile, displaying and matching listings and requests, enabling chat (text, photos, videos, and voice messages) between users, maintaining your wishlist, and remembering your settings. We use reports to keep the community safe: we review them and, when a user has been reported by five different people, their account is suspended automatically. Blocks are used only to stop the blocked person from messaging you.';

  @override
  String get privacy3Title => '3. Location Information';

  @override
  String get privacy3Body =>
      'If you select a location or province, it is used to show you relevant listings and requests in your area. You can change or clear this at any time in the app.';

  @override
  String get privacy4Title => '4. Sharing With Other Users';

  @override
  String get privacy4Body =>
      'Certain information is visible to other users as part of the app\'s normal operation, such as your profile name and photo on listings you post, and any messages, photos, videos, or voice messages you send through chat (chat media is stored privately and can only be opened by you and the person you sent it to). We do not sell your personal information to third parties. A report is seen only by us, and the person you report is not told who reported them. Blocking is private too: the person you block is not notified, but they can no longer message you.';

  @override
  String get privacy5Title => '5. Data Storage & Security';

  @override
  String get privacy5Body =>
      'Your account and app data are stored using Supabase, our backend service provider, with industry-standard security practices; this includes the chat photos, videos, and voice messages you send. While we take reasonable steps to protect your data, no method of storage or transmission is 100% secure.';

  @override
  String get privacy6Title => '6. Your Choices & Rights';

  @override
  String get privacy6Body =>
      'You can review and update your profile at any time from Edit Profile in Settings. You may request deletion of your account from Settings, which permanently removes your profile, listings, wishlist, chat media you sent, and associated data from our systems. In a chat you can clear the conversation (it is hidden from your view only, and the other person keeps their copy), and you can report, block or unblock a user at any time.';

  @override
  String get privacy7Title => '7. Data Retention';

  @override
  String get privacy7Body =>
      'We keep your information for as long as your account is active or as needed to provide the app\'s features. Once you delete your account, your personal data is removed except where we are required to retain it by law. Reports you send or that are made about you, and blocks, are deleted together with the account they belong to.';

  @override
  String get privacy8Title => '8. Children\'s Privacy';

  @override
  String get privacy8Body =>
      'PAO is not directed at children under 13, and we do not knowingly collect personal information from children under 13.';

  @override
  String get privacy9Title => '9. Changes to This Policy';

  @override
  String get privacy9Body =>
      'We may update this Privacy Policy from time to time. We will reflect the latest revision date at the top of this page.';

  @override
  String get privacy10Title => '10. Contact Us';

  @override
  String get privacy10Body =>
      'If you have questions about this Privacy Policy or how your data is handled, please reach out through the Help Center in Settings.';

  @override
  String get terms1Title => '1. Acceptance of Terms';

  @override
  String get terms1Body =>
      'By creating an account or using the PAO app, you agree to be bound by these Terms & Conditions. If you do not agree with any part of these terms, please do not use the app.';

  @override
  String get terms2Title => '2. Your Account';

  @override
  String get terms2Body =>
      'You must provide accurate information when creating your profile and are responsible for keeping your login credentials secure. You are responsible for all activity that happens under your account.';

  @override
  String get terms3Title => '3. Listings & Requests';

  @override
  String get terms3Body =>
      'When you add an item, post a request, or interact with listings, you agree that the information you provide is accurate, truthful, and does not violate any law or the rights of others. PAO may remove any listing or request that violates these terms.';

  @override
  String get terms4Title => '4. Role of PAO';

  @override
  String get terms4Body =>
      'PAO provides a platform that connects users to browse listings, send requests, and chat with one another. PAO is not a party to any agreement, transaction, or exchange between users and does not guarantee the accuracy, quality, safety, or legality of any listing or the conduct of any user.';

  @override
  String get terms5Title => '5. Chat & Communication';

  @override
  String get terms5Body =>
      'The in-app chat is provided to help users communicate about listings and requests. You agree not to use chat to send abusive, fraudulent, or unlawful content. Messages may be stored to provide and improve the service.';

  @override
  String get terms6Title => '6. Wishlist & Personalization';

  @override
  String get terms6Body =>
      'Features such as Wishlist and location-based browsing are provided for your convenience and are tied to your account. This data may be used to personalize what you see in the app.';

  @override
  String get terms7Title => '7. Account Deletion';

  @override
  String get terms7Body =>
      'You may delete your account at any time from Settings. Deleting your account will permanently remove your profile and associated data, as described in our Privacy Policy, and this action cannot be undone.';

  @override
  String get terms8Title => '8. Prohibited Conduct';

  @override
  String get terms8Body =>
      'You agree not to misuse the app, including but not limited to: posting illegal or misleading listings, harassing other users, attempting to access accounts that are not yours, or interfering with the normal operation of the app.';

  @override
  String get terms9Title => '9. Limitation of Liability';

  @override
  String get terms9Body =>
      'PAO is provided on an \"as is\" basis. To the fullest extent permitted by law, PAO and its team are not liable for any indirect, incidental, or consequential damages arising from your use of the app or your interactions with other users.';

  @override
  String get terms10Title => '10. Changes to These Terms';

  @override
  String get terms10Body =>
      'We may update these Terms & Conditions from time to time. Continued use of the app after changes are published means you accept the updated terms.';

  @override
  String get terms11Title => '11. Contact Us';

  @override
  String get terms11Body =>
      'If you have questions about these Terms & Conditions, please reach out through the Help Center in Settings.';

  @override
  String get viewMyProfile => 'View my profile';

  @override
  String get edit => 'Edit';

  @override
  String get editProduct => 'Edit Product';

  @override
  String get productUpdated => 'Product updated';

  @override
  String deleteProductConfirm(String name) {
    return 'Delete \"$name\"? Its requests, chats and wishlist entries will be removed too. This cannot be undone.';
  }

  @override
  String get productDeleted => 'Product deleted';

  @override
  String get failedToDeleteProduct =>
      'Failed to delete product. Please try again.';

  @override
  String get bugsAndFeatures => 'Bugs & Features';

  @override
  String get reportsIntro =>
      'Found something broken, or have an idea to make PAO better? Tell us here — we read every report.';

  @override
  String get reportTypeBug => 'Report a bug';

  @override
  String get reportTypeBugCaption => 'Something isn\'t working';

  @override
  String get reportTypeFeature => 'Suggest a feature';

  @override
  String get reportTypeFeatureCaption => 'An idea to improve the app';

  @override
  String get reportBugTitleLabel => 'What went wrong?';

  @override
  String get reportBugTitleHint =>
      'e.g. Chat doesn\'t open from a notification';

  @override
  String get reportFeatureTitleLabel => 'What\'s your idea?';

  @override
  String get reportFeatureTitleHint => 'e.g. Filter listings by distance';

  @override
  String get reportDetailsLabel => 'Details';

  @override
  String get reportBugDescriptionHint =>
      'What did you do, what happened, and what did you expect to happen?';

  @override
  String get reportFeatureDescriptionHint =>
      'Describe the feature and how it would help you.';

  @override
  String get reportTitleRequired => 'Please add a short title';

  @override
  String get reportDescriptionTooShort =>
      'Please add a bit more detail (at least 10 characters)';

  @override
  String get reportSubmitted => 'Thanks! We\'ve received it.';

  @override
  String get failedToSubmitReport => 'Couldn\'t send it. Please try again.';

  @override
  String get mustBeLoggedInReport => 'You must be logged in to send a report.';

  @override
  String get myReports => 'Your reports';

  @override
  String get noReportsYet =>
      'Nothing sent yet. Your bug reports and ideas will show up here.';

  @override
  String get failedToLoadReports =>
      'Couldn\'t load your reports. Pull down to try again.';

  @override
  String get reportStatusOpen => 'Received';

  @override
  String get reportStatusInProgress => 'In progress';

  @override
  String get reportStatusDone => 'Done';

  @override
  String get reportStatusClosed => 'Closed';

  @override
  String get attach => 'Attach';

  @override
  String get takePhoto => 'Take a photo';

  @override
  String get photosFromGallery => 'Photos from gallery';

  @override
  String get recordVideo => 'Record a video';

  @override
  String get videoFromGallery => 'Video from gallery';

  @override
  String get slideToCancel => 'Tap bin to cancel';

  @override
  String get releaseToCancel => 'Release to cancel';

  @override
  String get holdToRecordVoice =>
      'Voice message is too short. Tap the mic and speak for at least 1 second.';

  @override
  String get microphonePermissionDenied =>
      'Allow microphone access in Settings to send voice messages.';

  @override
  String get mediaTooLarge => 'That file is too large (max 50 MB).';

  @override
  String get photoLabel => 'Photo';

  @override
  String get videoLabel => 'Video';

  @override
  String get voiceMessageLabel => 'Voice message';

  @override
  String get updateYourApp => 'Update your App';

  @override
  String updateAvailableMessage(String current, String build) {
    return 'A new version of the app is available.\nInstalled: $current\nNew build: $build';
  }

  @override
  String get skip => 'Skip';

  @override
  String get update => 'Update';

  @override
  String get updateReadyTitle => 'Update ready';

  @override
  String get updateReadyMessage =>
      'The new version has been downloaded. Restart to finish updating.';

  @override
  String get restartToUpdate => 'Restart';

  @override
  String get onboardingGiveTitle => 'Give what you don\'t need';

  @override
  String get onboardingGiveBody =>
      'Post items you no longer use with photos and your location, and let someone nearby put them to good use.';

  @override
  String get onboardingFindTitle => 'Find what you need, free';

  @override
  String get onboardingFindBody =>
      'Search and filter by category, condition and city, then send a request to the giver.';

  @override
  String get onboardingChatTitle => 'Chat and get it done';

  @override
  String get onboardingChatBody =>
      'Talk with photos, videos and voice messages, then meet up and pick up your item.';

  @override
  String get whatsNewMediaTitle => 'Photos, videos & voice in chat';

  @override
  String get whatsNewMediaBody =>
      'Send pictures, video clips and voice messages right inside any chat.';

  @override
  String get whatsNewOfflineTitle => 'Saved on your phone';

  @override
  String get whatsNewOfflineBody =>
      'Media you open is kept on your device, so it loads instantly and works even without internet.';

  @override
  String get whatsNewDonorsTitle => 'Meet our donors';

  @override
  String get whatsNewDonorsBody =>
      'The new Donors tab celebrates the people who have given the most.';

  @override
  String get onboardingCommunityTitle => 'Join the community';

  @override
  String get onboardingCommunityBody =>
      'Every item given away is one less thing wasted and one more person helped. Ready to start?';

  @override
  String get whatsNewFastTitle => 'Opens instantly';

  @override
  String get whatsNewFastBody =>
      'Your feed, requests and wishlist now appear right away from your phone, then refresh in the background.';

  @override
  String get clearChat => 'Clear chat';

  @override
  String get clearChatAction => 'Clear';

  @override
  String get clearChatConfirm =>
      'All messages in this chat will be removed for you. The other person keeps their copy.';

  @override
  String get chatCleared => 'Chat cleared';

  @override
  String get reportUser => 'Report user';

  @override
  String get blockUser => 'Block user';

  @override
  String get unblockUser => 'Unblock';

  @override
  String get blockUserConfirm =>
      'They won\'t be able to send you messages. You can unblock them any time.';

  @override
  String get userBlocked => 'User blocked';

  @override
  String get userUnblocked => 'User unblocked';

  @override
  String get youBlockedThisUser => 'You blocked this user.';

  @override
  String get reportUserSubtitle => 'Why are you reporting this user?';

  @override
  String get reportReasonSpam => 'Spam';

  @override
  String get reportReasonHarassment => 'Harassment or abuse';

  @override
  String get reportReasonScam => 'Scam or fraud';

  @override
  String get reportReasonInappropriate => 'Inappropriate content';

  @override
  String get reportReasonOther => 'Other';

  @override
  String get reportDetailsHint => 'Add details (optional)';

  @override
  String get reportSent => 'Thanks, your report was sent.';

  @override
  String blockUserTitle(String name) {
    return 'Block $name?';
  }

  @override
  String reportUserTitle(String name) {
    return 'Report $name';
  }

  @override
  String get aboutTagline => 'Give what you don\'t need. Get what you do.';

  @override
  String get aboutPurposeTitle => 'Our purpose';

  @override
  String get aboutPurposeBody =>
      'PAO is a give-away marketplace. Instead of throwing away things you no longer need, post them for free so someone who needs them can have them. Browse what others are giving away, send a request, and arrange the handoff through in-app chat. Our goal is to reduce waste and help communities support each other.';

  @override
  String aboutVersionLabel(String version) {
    return 'Version $version';
  }

  @override
  String get aboutVersionHistory => 'Version history';

  @override
  String get aboutLatest => 'Latest';

  @override
  String get aboutWhatsNew => 'What\'s new';

  @override
  String get c100a =>
      'First release: post items for free and browse what others give away';

  @override
  String get c100b => 'Hosted Privacy Policy and Delete Account pages';

  @override
  String get c110a => 'English and Urdu language support';

  @override
  String get c110b => 'Password reset links now open inside the app';

  @override
  String get c110c => 'New users go straight to Home after sign up';

  @override
  String get c110d => 'Added the \"Used\" condition and the \"Other\" category';

  @override
  String get c111a => 'Live updates for chat, requests and posts';

  @override
  String get c111b => 'Faster listings with server-side pagination';

  @override
  String get c111c => 'Edit and delete your own posts';

  @override
  String get c120a => 'Push notifications';

  @override
  String get c120b => 'New floating bottom navigation bar';

  @override
  String get c120c => 'Improved profile tabs';

  @override
  String get c140a => 'Redesigned chat with unread badges and online presence';

  @override
  String get c140b => 'Send photos, videos and voice messages';

  @override
  String get c140c => 'New Bugs & Features report screen';

  @override
  String get c140d => 'Notifications on/off toggle';

  @override
  String get c140e => 'Branded dialogs and avatar ring style';

  @override
  String get c150a => 'New Donors tab';

  @override
  String get c150b => 'Chat request cards';

  @override
  String get c150c => 'Media compression for faster uploads';

  @override
  String get c150d => 'Local caching for smoother loading';

  @override
  String get c152a => 'Onboarding tour for new users';

  @override
  String get c152b => 'Chat safety: block and report users';

  @override
  String get c152c => 'Chat photos and videos available offline';

  @override
  String get c152d => 'Updated Privacy Policy';
}
