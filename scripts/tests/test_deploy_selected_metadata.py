import importlib.util
import json
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location(
    "deploy_selected_metadata",
    ROOT / "scripts" / "deploy_selected_metadata.py",
)
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class SelectedMetadataTests(unittest.TestCase):
    def test_custom_field_is_selected_by_exact_path(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            field = root / "force-app/main/default/objects/Account/fields/Test__c.field-meta.xml"
            field.parent.mkdir(parents=True)
            field.write_text("<CustomField/>")
            self.assertEqual(
                ["force-app/main/default/objects/Account/fields/Test__c.field-meta.xml"],
                MODULE.safe_paths(
                    ["force-app/main/default/objects/Account/fields/Test__c.field-meta.xml"],
                    root,
                ),
            )

    def test_apex_source_includes_companion_metadata(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "force-app/main/default/classes/Example.cls"
            source.parent.mkdir(parents=True)
            source.write_text("public class Example {}")
            Path(str(source) + "-meta.xml").write_text("<ApexClass/>")
            self.assertEqual(
                [
                    "force-app/main/default/classes/Example.cls",
                    "force-app/main/default/classes/Example.cls-meta.xml",
                ],
                MODULE.safe_paths(["force-app/main/default/classes/Example.cls"], root),
            )

    def test_missing_dependency_path_fails_before_cli(self):
        with tempfile.TemporaryDirectory() as directory:
            with self.assertRaisesRegex(ValueError, "does not exist"):
                MODULE.safe_paths(
                    ["force-app/main/default/classes/Missing.cls"],
                    Path(directory),
                )

    def test_path_traversal_is_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            with self.assertRaisesRegex(ValueError, "Unsafe"):
                MODULE.safe_paths(
                    ["force-app/main/default/../../secret"],
                    Path(directory),
                )

    def test_workflow_masks_tokens_and_validates_before_deploy(self):
        workflow = (ROOT / ".github/workflows/salesforce-oauth-deploy.yml").read_text()
        self.assertIn('print("::add-mask::" + claim["accessToken"])', workflow)
        self.assertNotIn("SF_CONTROL_ACCESS_TOKEN", workflow)
        self.assertIn("SF_CONTROL_TARGET_ORG=control-org", workflow)
        self.assertIn("github.event.repository.default_branch", workflow)
        self.assertIn("sparse-checkout: scripts", workflow)
        self.assertLess(workflow.index("ref: ${{ inputs.branch }}"), workflow.index("sparse-checkout: scripts"))
        self.assertLess(workflow.index("--mode validate"), workflow.index("--mode deploy"))
        self.assertNotIn("accessToken:", workflow)

    def test_approved_paths_file_is_json(self):
        payload = ["force-app/main/default/objects/Account/fields/Test__c.field-meta.xml"]
        self.assertEqual(payload, json.loads(json.dumps(payload)))


if __name__ == "__main__":
    unittest.main()
