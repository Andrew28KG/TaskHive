# TaskHive

Project UTS Pengembangan Aplikasi Mobile berbasis Flutter

A task management Flutter application that helps teams organize and track their tasks efficiently.

![TaskHive Logo](assets/images/logo.png)

## Author

Developed by Andrew28KG

## Features

TaskHive offers a comprehensive set of features to enhance team productivity:

- **Task Management**: Create, assign, and track tasks with due dates and priority levels
- **Team Collaboration**: Form teams, invite members, and collaborate on projects
- **Calendar View**: Visualize tasks and events in a calendar interface
- **Event Planning**: Schedule team meetings and events with attendee selection
- **Dashboard**: Get an overview of your tasks, upcoming deadlines, and team activities
- **User Profiles**: Customize your profile and manage notification preferences
- **Dark/Light Mode**: Choose between light and dark themes for comfortable viewing
- **Progress Tracking**: Monitor task completion and project progress
- **Analytics**: View insights on team performance and productivity metrics

## Getting Started

### Prerequisites

- Flutter SDK (version 2.0 or later)
- Dart SDK (version 2.12 or later)
- Firebase account (for authentication and database)

### Installation

1. Clone the repository:
   ```
   git clone https://github.com/Andrew28KG/TaskHive.git
   ```

2. Navigate to the project directory:
   ```
   cd TaskHive
   ```

3. Install dependencies:
   ```
   flutter pub get
   ```

4. Set up Firebase:
   - Create a Firebase project
   - Configure Flutter app with Firebase (follow Firebase Flutter documentation)
   - Add the required Firebase configuration files (not included in the repository)

5. Run the app:
   ```
   flutter run
   ```

## Usage Tutorial

### 1. Authentication
- **Sign Up**: Create a new account using email and password
- **Login**: Access your account with your credentials
- **Reset Password**: Use the "Forgot Password" option if needed

### 2. Dashboard
- View all your tasks, organized by priority and due date
- Tasks assigned to you are highlighted with an orange background and "Your Task" label
- Use the navigation menu to access other features

### 3. Task Management
- **Create Task**: Tap the floating action button (+) to create a new task
- **Assign Task**: Select team members to assign the task to
- **Set Priority**: Choose between low, medium, and high priority
- **Add Due Date**: Set a deadline for task completion
- **Add Description**: Provide detailed information about the task
- **Add Comments**: Discuss tasks with team members through comments

### 4. Calendar
- View tasks and events in a calendar layout
- Tap on a date to see all tasks and events for that day
- Create events by tapping the (+) button (team hosts only)
- Select event attendees from your team members

### 5. Team Management
- Create a new team or join existing teams
- Invite members to your team using their email addresses
- Assign roles (admin, member) to control permissions
- Collaborate on tasks and projects within your team

### 6. Progress Tracking
- Monitor task completion status
- Track project milestones and deadlines
- View team member contributions and activity

## Security Note

TaskHive takes security seriously:

- Authentication is handled through Firebase Authentication
- All data is stored securely in Firebase Cloud Firestore
- Sensitive API keys and configuration files are not included in the public repository
- User passwords are never stored in plain text
- Team data is protected with appropriate access controls

**Note**: If you fork or clone this repository, you will need to set up your own Firebase project and add the required configuration files.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

© 2023 TaskHive. All rights reserved.

## Resources

For help getting started with Flutter development:
- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)
- [Flutter documentation](https://docs.flutter.dev/)
