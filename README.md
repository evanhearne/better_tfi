# BetterTFI

An open-source alternative application to TFI Live, using the people's voice to shape feature set/functionality.

## What is BetterTFI ?

BetterTFI is an open source alternative dedicated to meeting the needs of the people of Ireland for an application to navigate public transport. Its main aims, from survey results, is to have minimal and easy to use features that allow the app to be performant when the user needs to navigate public transportation. 

The app works by using Flutter, a cross-platform application development framework, and Go.

Flutter is an open-source cross-platform development tool being used within this project to create the application itself. 

Go is a programming language which is being used for the backend component of the application. 

The NTA (National Transport Authority) has published their API for GTFSR (General Transit Feed Specification - Realtime) and Vehicles, but is limited to 5,000 requests per day from a default developer API key. Therefore, a custom backend which utilises the 5,000 requests per day will allow the app to still query for data without limits.

All of these components come together to form the app.

## Why BetterTFI ?

As is currently stands, there is no open source implementation of a navigation app for Ireland. This means there is a gap in the market to fill, where users or developers may appreciate seeing the source code of an application users may rely on to help them navigate their journey using public transport. 

This may be an employee/student who needs to commute, or a casual user wishing to spend the day in a new city. Users who can view the source code of a project can suggest new features or point out bugs that developers failed to catch, or even suggest fixes/new features through a PR.

As an alternative to TFI Live, users can have more choice within the market, and more choice can often lead to better results! 

## Getting Started

This project is a starting point for a Flutter application that follows the
[simple app state management
tutorial](https://flutter.dev/to/state-management-sample).

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Assets

The `assets` directory houses images, fonts, and any other files you want to
include with your application.

The `assets/images` directory contains [resolution-aware
images](https://flutter.dev/to/resolution-aware-images).

## Localization

This project generates localized messages based on arb files found in
the `lib/src/localization` directory.

To support additional languages, please visit the tutorial on
[Internationalizing Flutter apps](https://flutter.dev/to/internationalization).
