import bpy
import unittest
import logging
import os
import sys

class TEST_OT_run_test_suite(bpy.types.Operator):
    """Operator for running the unittest test suite."""
    bl_idname = "crwtiles.test_run_harness"
    bl_label = "Run Test Suite"

    def execute(self, context):
        print("Starting Test Harness...")

        try:
            # Dynamically import and run the test suite
            test_suite = self.load_test_suite()
            test_runner = unittest.TextTestRunner(verbosity=2)
            result = test_runner.run(test_suite)

            if result.wasSuccessful():
                self.report({'INFO'}, "All tests passed.")
                print("All tests passed.")
            else:
                self.report({'ERROR'}, "Some tests failed.")
                print("Some tests failed.")
        except Exception as e:
            print(f"Error while running tests: {e}")
            self.report({'ERROR'}, f"Test execution error: {e}")

        return {'FINISHED'}

    def load_test_suite(self) -> unittest.TestSuite:
        """Dynamically discover and load test cases from the tests directory."""
        # Build the path to the tests directory
        addon_dir = os.path.dirname(__file__)
        #tests_dir = os.path.join(addon_dir, "../tests")
        tests_dir = os.path.dirname("../tests")
        print("TESTS DIR", tests_dir)
        #sys.path.append(tests_dir)  # Add tests directory to sys.path


        print(f"Loading tests from: {tests_dir}")

        # Discover tests
        loader = unittest.TestLoader()
        suite = loader.discover(start_dir=tests_dir, pattern="test_*.py")

        if not suite:
            raise Exception("No tests found in the specified test directory.")

        print("Tests successfully loaded.")
        return suite

