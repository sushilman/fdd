# A sample application made to run in FDD

This sample application demonstrates how concurrency can be handled in actor model programming using isolates.

Just deploy the two 'Workers' via FDD manager:
    1. account.dart (Name isolateSystem as "bank" and worker as "account", deploy Only a single instance of this).
    2. UserEmulator.dart (Emulates the behavior of user, so multiple instances this worker is possible, it can be named anything for eg. isolateSystem as "bank" and worker as "user")
    

