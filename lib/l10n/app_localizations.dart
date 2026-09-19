import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ur.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ur'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'PAO'**
  String get appTitle;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @submit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get submit;

  /// No description provided for @apply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get apply;

  /// No description provided for @reset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get reset;

  /// No description provided for @continueLabel.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueLabel;

  /// No description provided for @paoUser.
  ///
  /// In en, this message translates to:
  /// **'PAO User'**
  String get paoUser;

  /// No description provided for @paoItem.
  ///
  /// In en, this message translates to:
  /// **'PAO item'**
  String get paoItem;

  /// No description provided for @yourName.
  ///
  /// In en, this message translates to:
  /// **'Your Name'**
  String get yourName;

  /// No description provided for @somethingWentWrong.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get somethingWentWrong;

  /// No description provided for @failedToUpdate.
  ///
  /// In en, this message translates to:
  /// **'Failed to update. Please try again.'**
  String get failedToUpdate;

  /// No description provided for @noInternet.
  ///
  /// In en, this message translates to:
  /// **'No internet connection. Please check your network and try again.'**
  String get noInternet;

  /// No description provided for @errorInvalidCredentials.
  ///
  /// In en, this message translates to:
  /// **'Incorrect email or password.'**
  String get errorInvalidCredentials;

  /// No description provided for @errorUserAlreadyExists.
  ///
  /// In en, this message translates to:
  /// **'An account with this email already exists.'**
  String get errorUserAlreadyExists;

  /// No description provided for @errorEmailNotConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Please confirm your email before logging in.'**
  String get errorEmailNotConfirmed;

  /// No description provided for @errorWeakPassword.
  ///
  /// In en, this message translates to:
  /// **'Please choose a stronger password.'**
  String get errorWeakPassword;

  /// No description provided for @errorRateLimited.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Please wait a moment and try again.'**
  String get errorRateLimited;

  /// No description provided for @welcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome Back'**
  String get welcomeBack;

  /// No description provided for @loginToContinue.
  ///
  /// In en, this message translates to:
  /// **'Login to continue'**
  String get loginToContinue;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @enterYourEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter your email'**
  String get enterYourEmail;

  /// No description provided for @emailRequired.
  ///
  /// In en, this message translates to:
  /// **'Email is required'**
  String get emailRequired;

  /// No description provided for @enterValidEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email'**
  String get enterValidEmail;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @enterYourPassword.
  ///
  /// In en, this message translates to:
  /// **'Enter your password'**
  String get enterYourPassword;

  /// No description provided for @passwordRequired.
  ///
  /// In en, this message translates to:
  /// **'Password is required'**
  String get passwordRequired;

  /// No description provided for @passwordMinLength.
  ///
  /// In en, this message translates to:
  /// **'Minimum 6 characters'**
  String get passwordMinLength;

  /// No description provided for @forgotPasswordQuestion.
  ///
  /// In en, this message translates to:
  /// **'Forgot Password?'**
  String get forgotPasswordQuestion;

  /// No description provided for @login.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get login;

  /// No description provided for @noAccountPrompt.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account? '**
  String get noAccountPrompt;

  /// No description provided for @signUp.
  ///
  /// In en, this message translates to:
  /// **'Sign Up'**
  String get signUp;

  /// No description provided for @acceptTermsToContinue.
  ///
  /// In en, this message translates to:
  /// **'Please accept the Terms & Conditions and Privacy Policy to continue.'**
  String get acceptTermsToContinue;

  /// No description provided for @createAccount.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get createAccount;

  /// No description provided for @signUpToGetStarted.
  ///
  /// In en, this message translates to:
  /// **'Sign up to get started'**
  String get signUpToGetStarted;

  /// No description provided for @fullName.
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get fullName;

  /// No description provided for @enterFullName.
  ///
  /// In en, this message translates to:
  /// **'Enter your full name'**
  String get enterFullName;

  /// No description provided for @nameRequired.
  ///
  /// In en, this message translates to:
  /// **'Name is required'**
  String get nameRequired;

  /// No description provided for @createPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Create a password'**
  String get createPasswordHint;

  /// No description provided for @confirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get confirmPassword;

  /// No description provided for @reenterPassword.
  ///
  /// In en, this message translates to:
  /// **'Re-enter your password'**
  String get reenterPassword;

  /// No description provided for @passwordsDoNotMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get passwordsDoNotMatch;

  /// No description provided for @checkEmailToConfirm.
  ///
  /// In en, this message translates to:
  /// **'Check your email to confirm your account, then log in.'**
  String get checkEmailToConfirm;

  /// No description provided for @haveAccountPrompt.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? '**
  String get haveAccountPrompt;

  /// No description provided for @forgotPasswordInstructions.
  ///
  /// In en, this message translates to:
  /// **'Enter your email and we\'ll send you a link to reset your password.'**
  String get forgotPasswordInstructions;

  /// No description provided for @resetLinkSent.
  ///
  /// In en, this message translates to:
  /// **'Reset link sent! Check your inbox.'**
  String get resetLinkSent;

  /// No description provided for @sendResetLink.
  ///
  /// In en, this message translates to:
  /// **'Send Reset Link'**
  String get sendResetLink;

  /// No description provided for @backToLogin.
  ///
  /// In en, this message translates to:
  /// **'Back to Login'**
  String get backToLogin;

  /// No description provided for @termsAgreePrefix.
  ///
  /// In en, this message translates to:
  /// **'I agree to the '**
  String get termsAgreePrefix;

  /// No description provided for @termsAnd.
  ///
  /// In en, this message translates to:
  /// **' and '**
  String get termsAnd;

  /// No description provided for @termsAgreeSuffix.
  ///
  /// In en, this message translates to:
  /// **''**
  String get termsAgreeSuffix;

  /// No description provided for @termsAndConditions.
  ///
  /// In en, this message translates to:
  /// **'Terms & Conditions'**
  String get termsAndConditions;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navWishlist.
  ///
  /// In en, this message translates to:
  /// **'Wishlist'**
  String get navWishlist;

  /// No description provided for @navRequests.
  ///
  /// In en, this message translates to:
  /// **'Requests'**
  String get navRequests;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @welcomeBackGreeting.
  ///
  /// In en, this message translates to:
  /// **'Welcome back 👋'**
  String get welcomeBackGreeting;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search...'**
  String get searchHint;

  /// No description provided for @noProductsFound.
  ///
  /// In en, this message translates to:
  /// **'No products found'**
  String get noProductsFound;

  /// No description provided for @tryDifferentSearch.
  ///
  /// In en, this message translates to:
  /// **'Try a different search term or clear your filters'**
  String get tryDifferentSearch;

  /// No description provided for @clearSearch.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get clearSearch;

  /// No description provided for @categoryAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get categoryAll;

  /// No description provided for @categoryElectronics.
  ///
  /// In en, this message translates to:
  /// **'Electronics'**
  String get categoryElectronics;

  /// No description provided for @categoryFashion.
  ///
  /// In en, this message translates to:
  /// **'Fashion'**
  String get categoryFashion;

  /// No description provided for @categoryHomeLiving.
  ///
  /// In en, this message translates to:
  /// **'Home & Living'**
  String get categoryHomeLiving;

  /// No description provided for @categoryBeauty.
  ///
  /// In en, this message translates to:
  /// **'Beauty'**
  String get categoryBeauty;

  /// No description provided for @categorySports.
  ///
  /// In en, this message translates to:
  /// **'Sports'**
  String get categorySports;

  /// No description provided for @categoryBooks.
  ///
  /// In en, this message translates to:
  /// **'Books'**
  String get categoryBooks;

  /// No description provided for @categoryToys.
  ///
  /// In en, this message translates to:
  /// **'Toys'**
  String get categoryToys;

  /// No description provided for @categoryOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get categoryOther;

  /// No description provided for @conditionNew.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get conditionNew;

  /// No description provided for @conditionUsed.
  ///
  /// In en, this message translates to:
  /// **'Used'**
  String get conditionUsed;

  /// No description provided for @conditionOld.
  ///
  /// In en, this message translates to:
  /// **'Old'**
  String get conditionOld;

  /// No description provided for @sortNewest.
  ///
  /// In en, this message translates to:
  /// **'Newest'**
  String get sortNewest;

  /// No description provided for @filters.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get filters;

  /// No description provided for @category.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get category;

  /// No description provided for @sortBy.
  ///
  /// In en, this message translates to:
  /// **'Sort By'**
  String get sortBy;

  /// No description provided for @condition.
  ///
  /// In en, this message translates to:
  /// **'Condition'**
  String get condition;

  /// No description provided for @shareProduct.
  ///
  /// In en, this message translates to:
  /// **'Check out \"{name}\" on PAO!'**
  String shareProduct(String name);

  /// No description provided for @requestedProduct.
  ///
  /// In en, this message translates to:
  /// **'Requested \"{name}\" — chat with the owner anytime'**
  String requestedProduct(String name);

  /// No description provided for @failedToSendRequest.
  ///
  /// In en, this message translates to:
  /// **'Failed to send request. Please try again.'**
  String get failedToSendRequest;

  /// No description provided for @cantRequestOwnItem.
  ///
  /// In en, this message translates to:
  /// **'You can\'t request your own item.'**
  String get cantRequestOwnItem;

  /// No description provided for @markAsGiven.
  ///
  /// In en, this message translates to:
  /// **'Mark as Given'**
  String get markAsGiven;

  /// No description provided for @markAsGivenConfirm.
  ///
  /// In en, this message translates to:
  /// **'Have you given \"{name}\" to someone? It will be removed from the listing.'**
  String markAsGivenConfirm(String name);

  /// No description provided for @yesGiven.
  ///
  /// In en, this message translates to:
  /// **'Yes, Given'**
  String get yesGiven;

  /// No description provided for @messageOwner.
  ///
  /// In en, this message translates to:
  /// **'Message Owner'**
  String get messageOwner;

  /// No description provided for @giveMe.
  ///
  /// In en, this message translates to:
  /// **'Give Me'**
  String get giveMe;

  /// No description provided for @postedBy.
  ///
  /// In en, this message translates to:
  /// **'Posted by'**
  String get postedBy;

  /// No description provided for @description.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get description;

  /// No description provided for @noDescription.
  ///
  /// In en, this message translates to:
  /// **'No description available for this product.'**
  String get noDescription;

  /// No description provided for @addProduct.
  ///
  /// In en, this message translates to:
  /// **'Add Product'**
  String get addProduct;

  /// No description provided for @giveSomethingAway.
  ///
  /// In en, this message translates to:
  /// **'Give something away for free'**
  String get giveSomethingAway;

  /// No description provided for @addItemSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Books, electronics, or anything else someone could use'**
  String get addItemSubtitle;

  /// No description provided for @photos.
  ///
  /// In en, this message translates to:
  /// **'Photos'**
  String get photos;

  /// No description provided for @title.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get title;

  /// No description provided for @titleHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Wireless Headphones'**
  String get titleHint;

  /// No description provided for @titleRequired.
  ///
  /// In en, this message translates to:
  /// **'Title is required'**
  String get titleRequired;

  /// No description provided for @describeItemHint.
  ///
  /// In en, this message translates to:
  /// **'Describe the item and its condition'**
  String get describeItemHint;

  /// No description provided for @descriptionRequired.
  ///
  /// In en, this message translates to:
  /// **'Description is required'**
  String get descriptionRequired;

  /// No description provided for @postForFree.
  ///
  /// In en, this message translates to:
  /// **'Post for Free'**
  String get postForFree;

  /// No description provided for @addPhoto.
  ///
  /// In en, this message translates to:
  /// **'Add Photo'**
  String get addPhoto;

  /// No description provided for @camera.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get camera;

  /// No description provided for @gallery.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get gallery;

  /// No description provided for @pleaseSelectCategory.
  ///
  /// In en, this message translates to:
  /// **'Please select a category'**
  String get pleaseSelectCategory;

  /// No description provided for @failedToPostItem.
  ///
  /// In en, this message translates to:
  /// **'Failed to post item.'**
  String get failedToPostItem;

  /// No description provided for @productPosted.
  ///
  /// In en, this message translates to:
  /// **'Product posted for free giveaway'**
  String get productPosted;

  /// No description provided for @mustBeLoggedInToPost.
  ///
  /// In en, this message translates to:
  /// **'You must be logged in to post an item.'**
  String get mustBeLoggedInToPost;

  /// No description provided for @requests.
  ///
  /// In en, this message translates to:
  /// **'Requests'**
  String get requests;

  /// No description provided for @tabSent.
  ///
  /// In en, this message translates to:
  /// **'Sent'**
  String get tabSent;

  /// No description provided for @tabReceived.
  ///
  /// In en, this message translates to:
  /// **'Received'**
  String get tabReceived;

  /// No description provided for @emptySentMessage.
  ///
  /// In en, this message translates to:
  /// **'Tap \"Give Me\" on a product to request it'**
  String get emptySentMessage;

  /// No description provided for @emptyReceivedMessage.
  ///
  /// In en, this message translates to:
  /// **'Requests for the items you post will show up here'**
  String get emptyReceivedMessage;

  /// No description provided for @statusGivenToYou.
  ///
  /// In en, this message translates to:
  /// **'Given to you'**
  String get statusGivenToYou;

  /// No description provided for @statusNotSelected.
  ///
  /// In en, this message translates to:
  /// **'Not selected'**
  String get statusNotSelected;

  /// No description provided for @statusDeclined.
  ///
  /// In en, this message translates to:
  /// **'Declined'**
  String get statusDeclined;

  /// No description provided for @statusPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get statusPending;

  /// No description provided for @requestTo.
  ///
  /// In en, this message translates to:
  /// **'to {name}'**
  String requestTo(String name);

  /// No description provided for @requestFrom.
  ///
  /// In en, this message translates to:
  /// **'from {name}'**
  String requestFrom(String name);

  /// No description provided for @acceptAndGive.
  ///
  /// In en, this message translates to:
  /// **'Accept & Give'**
  String get acceptAndGive;

  /// No description provided for @leaveFeedback.
  ///
  /// In en, this message translates to:
  /// **'Leave Feedback'**
  String get leaveFeedback;

  /// No description provided for @noRequestsYet.
  ///
  /// In en, this message translates to:
  /// **'No requests yet'**
  String get noRequestsYet;

  /// No description provided for @giveThisItem.
  ///
  /// In en, this message translates to:
  /// **'Give this item'**
  String get giveThisItem;

  /// No description provided for @giveThisItemConfirm.
  ///
  /// In en, this message translates to:
  /// **'Give \"{name}\" to this person? Other requests for it will be closed.'**
  String giveThisItemConfirm(String name);

  /// No description provided for @yesGive.
  ///
  /// In en, this message translates to:
  /// **'Yes, Give'**
  String get yesGive;

  /// No description provided for @itemMarkedAsGiven.
  ///
  /// In en, this message translates to:
  /// **'Item marked as given'**
  String get itemMarkedAsGiven;

  /// No description provided for @thanksForFeedback.
  ///
  /// In en, this message translates to:
  /// **'Thanks for your feedback!'**
  String get thanksForFeedback;

  /// No description provided for @acceptAndGiveThisItem.
  ///
  /// In en, this message translates to:
  /// **'Accept & Give This Item'**
  String get acceptAndGiveThisItem;

  /// No description provided for @receivedLeaveFeedback.
  ///
  /// In en, this message translates to:
  /// **'You received this — Leave Feedback'**
  String get receivedLeaveFeedback;

  /// No description provided for @sayHello.
  ///
  /// In en, this message translates to:
  /// **'Say hello 👋'**
  String get sayHello;

  /// No description provided for @typeMessageHint.
  ///
  /// In en, this message translates to:
  /// **'Type a message...'**
  String get typeMessageHint;

  /// No description provided for @deleteMessage.
  ///
  /// In en, this message translates to:
  /// **'Delete message'**
  String get deleteMessage;

  /// No description provided for @deleteMessageConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete this message? This cannot be undone.'**
  String get deleteMessageConfirm;

  /// No description provided for @failedToDeleteMessage.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete message. Please try again.'**
  String get failedToDeleteMessage;

  /// No description provided for @failedToLoadMessages.
  ///
  /// In en, this message translates to:
  /// **'Failed to load messages.'**
  String get failedToLoadMessages;

  /// No description provided for @failedToSendMessage.
  ///
  /// In en, this message translates to:
  /// **'Failed to send message.'**
  String get failedToSendMessage;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @tabPosts.
  ///
  /// In en, this message translates to:
  /// **'Posts'**
  String get tabPosts;

  /// No description provided for @tabGivenAway.
  ///
  /// In en, this message translates to:
  /// **'Given Away'**
  String get tabGivenAway;

  /// No description provided for @noPostsYet.
  ///
  /// In en, this message translates to:
  /// **'No posts yet.'**
  String get noPostsYet;

  /// No description provided for @nothingGivenAwayYet.
  ///
  /// In en, this message translates to:
  /// **'Nothing given away yet.'**
  String get nothingGivenAwayYet;

  /// No description provided for @donated.
  ///
  /// In en, this message translates to:
  /// **'Donated'**
  String get donated;

  /// No description provided for @noRatings.
  ///
  /// In en, this message translates to:
  /// **'No ratings'**
  String get noRatings;

  /// No description provided for @reviewCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 review} other{{count} reviews}}'**
  String reviewCount(int count);

  /// No description provided for @feedback.
  ///
  /// In en, this message translates to:
  /// **'Feedback'**
  String get feedback;

  /// No description provided for @noFeedbackYet.
  ///
  /// In en, this message translates to:
  /// **'No feedback yet.'**
  String get noFeedbackYet;

  /// No description provided for @timeMonthsAgo.
  ///
  /// In en, this message translates to:
  /// **'{count}mo ago'**
  String timeMonthsAgo(int count);

  /// No description provided for @timeDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'{count}d ago'**
  String timeDaysAgo(int count);

  /// No description provided for @timeHoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{count}h ago'**
  String timeHoursAgo(int count);

  /// No description provided for @timeMinutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{count}m ago'**
  String timeMinutesAgo(int count);

  /// No description provided for @timeJustNow.
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get timeJustNow;

  /// No description provided for @pleaseSelectRating.
  ///
  /// In en, this message translates to:
  /// **'Please select a rating'**
  String get pleaseSelectRating;

  /// No description provided for @failedToSubmitFeedback.
  ///
  /// In en, this message translates to:
  /// **'Failed to submit feedback. Please try again.'**
  String get failedToSubmitFeedback;

  /// No description provided for @rateThisExchange.
  ///
  /// In en, this message translates to:
  /// **'Rate this exchange'**
  String get rateThisExchange;

  /// No description provided for @leaveCommentHint.
  ///
  /// In en, this message translates to:
  /// **'Leave a comment (optional)'**
  String get leaveCommentHint;

  /// No description provided for @wishlist.
  ///
  /// In en, this message translates to:
  /// **'Wishlist'**
  String get wishlist;

  /// No description provided for @wishlistEmpty.
  ///
  /// In en, this message translates to:
  /// **'Your wishlist is empty'**
  String get wishlistEmpty;

  /// No description provided for @wishlistEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Tap the Add button to save something'**
  String get wishlistEmptyHint;

  /// No description provided for @selectYourLocation.
  ///
  /// In en, this message translates to:
  /// **'Select Your Location'**
  String get selectYourLocation;

  /// No description provided for @addAddressToFinish.
  ///
  /// In en, this message translates to:
  /// **'Add your address to finish setting up your account'**
  String get addAddressToFinish;

  /// No description provided for @country.
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get country;

  /// No description provided for @countryPakistan.
  ///
  /// In en, this message translates to:
  /// **'Pakistan'**
  String get countryPakistan;

  /// No description provided for @province.
  ///
  /// In en, this message translates to:
  /// **'Province'**
  String get province;

  /// No description provided for @selectProvinceHint.
  ///
  /// In en, this message translates to:
  /// **'Select your province'**
  String get selectProvinceHint;

  /// No description provided for @provinceRequired.
  ///
  /// In en, this message translates to:
  /// **'Province is required'**
  String get provinceRequired;

  /// No description provided for @city.
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get city;

  /// No description provided for @selectCityHint.
  ///
  /// In en, this message translates to:
  /// **'Select your city'**
  String get selectCityHint;

  /// No description provided for @cityRequired.
  ///
  /// In en, this message translates to:
  /// **'City is required'**
  String get cityRequired;

  /// No description provided for @address.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get address;

  /// No description provided for @enterAddressHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your address'**
  String get enterAddressHint;

  /// No description provided for @addressRequired.
  ///
  /// In en, this message translates to:
  /// **'Address is required'**
  String get addressRequired;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @sectionGeneral.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get sectionGeneral;

  /// No description provided for @sectionLegal.
  ///
  /// In en, this message translates to:
  /// **'Legal'**
  String get sectionLegal;

  /// No description provided for @sectionSupport.
  ///
  /// In en, this message translates to:
  /// **'Support'**
  String get sectionSupport;

  /// No description provided for @editProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get editProfile;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @helpCenter.
  ///
  /// In en, this message translates to:
  /// **'Help Center'**
  String get helpCenter;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// No description provided for @deleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get deleteAccount;

  /// No description provided for @deleteAccountConfirm.
  ///
  /// In en, this message translates to:
  /// **'This will permanently delete your account and all your data. This action cannot be undone.'**
  String get deleteAccountConfirm;

  /// No description provided for @failedToDeleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete account. Please try again.'**
  String get failedToDeleteAccount;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System Default'**
  String get themeSystem;

  /// No description provided for @themeLightSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Bright background, dark text'**
  String get themeLightSubtitle;

  /// No description provided for @themeDarkSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Dark background, light text'**
  String get themeDarkSubtitle;

  /// No description provided for @themeSystemSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Matches your device setting'**
  String get themeSystemSubtitle;

  /// No description provided for @chooseHowPaoLooks.
  ///
  /// In en, this message translates to:
  /// **'Choose how PAO looks'**
  String get chooseHowPaoLooks;

  /// No description provided for @searchLanguage.
  ///
  /// In en, this message translates to:
  /// **'Search language'**
  String get searchLanguage;

  /// No description provided for @noLanguagesFound.
  ///
  /// In en, this message translates to:
  /// **'No languages found'**
  String get noLanguagesFound;

  /// No description provided for @languageSetTo.
  ///
  /// In en, this message translates to:
  /// **'Language set to {name}'**
  String languageSetTo(String name);

  /// No description provided for @failedToUpdateProfile.
  ///
  /// In en, this message translates to:
  /// **'Failed to update profile.'**
  String get failedToUpdateProfile;

  /// No description provided for @profileUpdatedConfirmEmail.
  ///
  /// In en, this message translates to:
  /// **'Profile updated. Check your new email to confirm the change.'**
  String get profileUpdatedConfirmEmail;

  /// No description provided for @profileUpdated.
  ///
  /// In en, this message translates to:
  /// **'Profile updated'**
  String get profileUpdated;

  /// No description provided for @phoneOptional.
  ///
  /// In en, this message translates to:
  /// **'Phone (optional)'**
  String get phoneOptional;

  /// No description provided for @enterPhoneHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your phone number'**
  String get enterPhoneHint;

  /// No description provided for @bioOptional.
  ///
  /// In en, this message translates to:
  /// **'Bio (optional)'**
  String get bioOptional;

  /// No description provided for @bioHint.
  ///
  /// In en, this message translates to:
  /// **'Tell us a little about yourself'**
  String get bioHint;

  /// No description provided for @saveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get saveChanges;

  /// No description provided for @mustBeLoggedInPhoto.
  ///
  /// In en, this message translates to:
  /// **'You must be logged in to update your photo.'**
  String get mustBeLoggedInPhoto;

  /// No description provided for @failedToUpdatePhoto.
  ///
  /// In en, this message translates to:
  /// **'Failed to update photo. Please try again.'**
  String get failedToUpdatePhoto;

  /// No description provided for @mustBeLoggedInProfile.
  ///
  /// In en, this message translates to:
  /// **'You must be logged in to update your profile.'**
  String get mustBeLoggedInProfile;

  /// No description provided for @frequentlyAskedQuestions.
  ///
  /// In en, this message translates to:
  /// **'Frequently asked questions'**
  String get frequentlyAskedQuestions;

  /// No description provided for @stillNeedHelp.
  ///
  /// In en, this message translates to:
  /// **'Still need help?'**
  String get stillNeedHelp;

  /// No description provided for @cantFindWhatYouNeed.
  ///
  /// In en, this message translates to:
  /// **'Can\'t find what you\'re looking for? More ways to reach us will show up here soon.'**
  String get cantFindWhatYouNeed;

  /// No description provided for @faq1Q.
  ///
  /// In en, this message translates to:
  /// **'How do I give away an item?'**
  String get faq1Q;

  /// No description provided for @faq1A.
  ///
  /// In en, this message translates to:
  /// **'Tap the purple + button on the home screen, add a few photos, a title, description, category and condition, then post it. It will show up in listings right away.'**
  String get faq1A;

  /// No description provided for @faq2Q.
  ///
  /// In en, this message translates to:
  /// **'How do I request an item?'**
  String get faq2Q;

  /// No description provided for @faq2A.
  ///
  /// In en, this message translates to:
  /// **'Open any listing and tap \"Give Me\". This sends a request to the owner and lets you chat with them about it.'**
  String get faq2A;

  /// No description provided for @faq3Q.
  ///
  /// In en, this message translates to:
  /// **'How do I chat with the owner or requester?'**
  String get faq3Q;

  /// No description provided for @faq3A.
  ///
  /// In en, this message translates to:
  /// **'Once a request has been sent, open it from the Inbox or tap \"Message Owner\" on the listing to start chatting.'**
  String get faq3A;

  /// No description provided for @faq4Q.
  ///
  /// In en, this message translates to:
  /// **'How do I accept a request for my item?'**
  String get faq4Q;

  /// No description provided for @faq4A.
  ///
  /// In en, this message translates to:
  /// **'Open the chat for that request and tap \"Accept & Give This Item\". This marks the item as given and closes any other pending requests on it.'**
  String get faq4A;

  /// No description provided for @faq5Q.
  ///
  /// In en, this message translates to:
  /// **'How do I save an item to my Wishlist?'**
  String get faq5Q;

  /// No description provided for @faq5A.
  ///
  /// In en, this message translates to:
  /// **'Tap the heart icon on any listing. You can find everything you\'ve saved under Settings > Wishlist.'**
  String get faq5A;

  /// No description provided for @faq6Q.
  ///
  /// In en, this message translates to:
  /// **'Can I change the app language or theme?'**
  String get faq6Q;

  /// No description provided for @faq6A.
  ///
  /// In en, this message translates to:
  /// **'Yes — go to Settings and open Language or Theme to switch between English and Urdu, or between light, dark, or your device\'s default.'**
  String get faq6A;

  /// No description provided for @faq7Q.
  ///
  /// In en, this message translates to:
  /// **'How do I edit my profile?'**
  String get faq7Q;

  /// No description provided for @faq7A.
  ///
  /// In en, this message translates to:
  /// **'Go to Settings > Edit Profile to update your name, photo, and other details.'**
  String get faq7A;

  /// No description provided for @faq8Q.
  ///
  /// In en, this message translates to:
  /// **'How do I delete my account?'**
  String get faq8Q;

  /// No description provided for @faq8A.
  ///
  /// In en, this message translates to:
  /// **'Go to Settings > Delete Account. This permanently removes your profile and data and cannot be undone.'**
  String get faq8A;

  /// No description provided for @faq9Q.
  ///
  /// In en, this message translates to:
  /// **'Is my data safe?'**
  String get faq9Q;

  /// No description provided for @faq9A.
  ///
  /// In en, this message translates to:
  /// **'We only use your information to run the app\'s features. See our Privacy Policy under Settings > Legal for the full details.'**
  String get faq9A;

  /// No description provided for @legalLastUpdated.
  ///
  /// In en, this message translates to:
  /// **'Last updated: {date}'**
  String legalLastUpdated(String date);

  /// No description provided for @legalDate.
  ///
  /// In en, this message translates to:
  /// **'September 18, 2026'**
  String get legalDate;

  /// No description provided for @privacy1Title.
  ///
  /// In en, this message translates to:
  /// **'1. Information We Collect'**
  String get privacy1Title;

  /// No description provided for @privacy1Body.
  ///
  /// In en, this message translates to:
  /// **'We collect information you provide directly, such as your name, email address, profile photo, and the listings, requests, or messages you create. We also collect information generated by using the app, such as your wishlist, saved location/province, and app preferences (theme, language).'**
  String get privacy1Body;

  /// No description provided for @privacy2Title.
  ///
  /// In en, this message translates to:
  /// **'2. How We Use Your Information'**
  String get privacy2Title;

  /// No description provided for @privacy2Body.
  ///
  /// In en, this message translates to:
  /// **'We use your information to operate the app\'s core features: showing your profile, displaying and matching listings and requests, enabling chat between users, maintaining your wishlist, and remembering your settings.'**
  String get privacy2Body;

  /// No description provided for @privacy3Title.
  ///
  /// In en, this message translates to:
  /// **'3. Location Information'**
  String get privacy3Title;

  /// No description provided for @privacy3Body.
  ///
  /// In en, this message translates to:
  /// **'If you select a location or province, it is used to show you relevant listings and requests in your area. You can change or clear this at any time in the app.'**
  String get privacy3Body;

  /// No description provided for @privacy4Title.
  ///
  /// In en, this message translates to:
  /// **'4. Sharing With Other Users'**
  String get privacy4Title;

  /// No description provided for @privacy4Body.
  ///
  /// In en, this message translates to:
  /// **'Certain information is visible to other users as part of the app\'s normal operation, such as your profile name and photo on listings you post, and any messages you send through chat. We do not sell your personal information to third parties.'**
  String get privacy4Body;

  /// No description provided for @privacy5Title.
  ///
  /// In en, this message translates to:
  /// **'5. Data Storage & Security'**
  String get privacy5Title;

  /// No description provided for @privacy5Body.
  ///
  /// In en, this message translates to:
  /// **'Your account and app data are stored using Supabase, our backend service provider, with industry-standard security practices. While we take reasonable steps to protect your data, no method of storage or transmission is 100% secure.'**
  String get privacy5Body;

  /// No description provided for @privacy6Title.
  ///
  /// In en, this message translates to:
  /// **'6. Your Choices & Rights'**
  String get privacy6Title;

  /// No description provided for @privacy6Body.
  ///
  /// In en, this message translates to:
  /// **'You can review and update your profile at any time from Edit Profile in Settings. You may request deletion of your account from Settings, which permanently removes your profile, listings, wishlist, and associated data from our systems.'**
  String get privacy6Body;

  /// No description provided for @privacy7Title.
  ///
  /// In en, this message translates to:
  /// **'7. Data Retention'**
  String get privacy7Title;

  /// No description provided for @privacy7Body.
  ///
  /// In en, this message translates to:
  /// **'We keep your information for as long as your account is active or as needed to provide the app\'s features. Once you delete your account, your personal data is removed except where we are required to retain it by law.'**
  String get privacy7Body;

  /// No description provided for @privacy8Title.
  ///
  /// In en, this message translates to:
  /// **'8. Children\'s Privacy'**
  String get privacy8Title;

  /// No description provided for @privacy8Body.
  ///
  /// In en, this message translates to:
  /// **'PAO is not directed at children under 13, and we do not knowingly collect personal information from children under 13.'**
  String get privacy8Body;

  /// No description provided for @privacy9Title.
  ///
  /// In en, this message translates to:
  /// **'9. Changes to This Policy'**
  String get privacy9Title;

  /// No description provided for @privacy9Body.
  ///
  /// In en, this message translates to:
  /// **'We may update this Privacy Policy from time to time. We will reflect the latest revision date at the top of this page.'**
  String get privacy9Body;

  /// No description provided for @privacy10Title.
  ///
  /// In en, this message translates to:
  /// **'10. Contact Us'**
  String get privacy10Title;

  /// No description provided for @privacy10Body.
  ///
  /// In en, this message translates to:
  /// **'If you have questions about this Privacy Policy or how your data is handled, please reach out through the Help Center in Settings.'**
  String get privacy10Body;

  /// No description provided for @terms1Title.
  ///
  /// In en, this message translates to:
  /// **'1. Acceptance of Terms'**
  String get terms1Title;

  /// No description provided for @terms1Body.
  ///
  /// In en, this message translates to:
  /// **'By creating an account or using the PAO app, you agree to be bound by these Terms & Conditions. If you do not agree with any part of these terms, please do not use the app.'**
  String get terms1Body;

  /// No description provided for @terms2Title.
  ///
  /// In en, this message translates to:
  /// **'2. Your Account'**
  String get terms2Title;

  /// No description provided for @terms2Body.
  ///
  /// In en, this message translates to:
  /// **'You must provide accurate information when creating your profile and are responsible for keeping your login credentials secure. You are responsible for all activity that happens under your account.'**
  String get terms2Body;

  /// No description provided for @terms3Title.
  ///
  /// In en, this message translates to:
  /// **'3. Listings & Requests'**
  String get terms3Title;

  /// No description provided for @terms3Body.
  ///
  /// In en, this message translates to:
  /// **'When you add an item, post a request, or interact with listings, you agree that the information you provide is accurate, truthful, and does not violate any law or the rights of others. PAO may remove any listing or request that violates these terms.'**
  String get terms3Body;

  /// No description provided for @terms4Title.
  ///
  /// In en, this message translates to:
  /// **'4. Role of PAO'**
  String get terms4Title;

  /// No description provided for @terms4Body.
  ///
  /// In en, this message translates to:
  /// **'PAO provides a platform that connects users to browse listings, send requests, and chat with one another. PAO is not a party to any agreement, transaction, or exchange between users and does not guarantee the accuracy, quality, safety, or legality of any listing or the conduct of any user.'**
  String get terms4Body;

  /// No description provided for @terms5Title.
  ///
  /// In en, this message translates to:
  /// **'5. Chat & Communication'**
  String get terms5Title;

  /// No description provided for @terms5Body.
  ///
  /// In en, this message translates to:
  /// **'The in-app chat is provided to help users communicate about listings and requests. You agree not to use chat to send abusive, fraudulent, or unlawful content. Messages may be stored to provide and improve the service.'**
  String get terms5Body;

  /// No description provided for @terms6Title.
  ///
  /// In en, this message translates to:
  /// **'6. Wishlist & Personalization'**
  String get terms6Title;

  /// No description provided for @terms6Body.
  ///
  /// In en, this message translates to:
  /// **'Features such as Wishlist and location-based browsing are provided for your convenience and are tied to your account. This data may be used to personalize what you see in the app.'**
  String get terms6Body;

  /// No description provided for @terms7Title.
  ///
  /// In en, this message translates to:
  /// **'7. Account Deletion'**
  String get terms7Title;

  /// No description provided for @terms7Body.
  ///
  /// In en, this message translates to:
  /// **'You may delete your account at any time from Settings. Deleting your account will permanently remove your profile and associated data, as described in our Privacy Policy, and this action cannot be undone.'**
  String get terms7Body;

  /// No description provided for @terms8Title.
  ///
  /// In en, this message translates to:
  /// **'8. Prohibited Conduct'**
  String get terms8Title;

  /// No description provided for @terms8Body.
  ///
  /// In en, this message translates to:
  /// **'You agree not to misuse the app, including but not limited to: posting illegal or misleading listings, harassing other users, attempting to access accounts that are not yours, or interfering with the normal operation of the app.'**
  String get terms8Body;

  /// No description provided for @terms9Title.
  ///
  /// In en, this message translates to:
  /// **'9. Limitation of Liability'**
  String get terms9Title;

  /// No description provided for @terms9Body.
  ///
  /// In en, this message translates to:
  /// **'PAO is provided on an \"as is\" basis. To the fullest extent permitted by law, PAO and its team are not liable for any indirect, incidental, or consequential damages arising from your use of the app or your interactions with other users.'**
  String get terms9Body;

  /// No description provided for @terms10Title.
  ///
  /// In en, this message translates to:
  /// **'10. Changes to These Terms'**
  String get terms10Title;

  /// No description provided for @terms10Body.
  ///
  /// In en, this message translates to:
  /// **'We may update these Terms & Conditions from time to time. Continued use of the app after changes are published means you accept the updated terms.'**
  String get terms10Body;

  /// No description provided for @terms11Title.
  ///
  /// In en, this message translates to:
  /// **'11. Contact Us'**
  String get terms11Title;

  /// No description provided for @terms11Body.
  ///
  /// In en, this message translates to:
  /// **'If you have questions about these Terms & Conditions, please reach out through the Help Center in Settings.'**
  String get terms11Body;

  /// No description provided for @viewMyProfile.
  ///
  /// In en, this message translates to:
  /// **'View my profile'**
  String get viewMyProfile;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ur'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ur':
      return AppLocalizationsUr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
