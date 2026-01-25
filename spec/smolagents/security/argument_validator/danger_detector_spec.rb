require "spec_helper"

RSpec.describe Smolagents::Security::DangerDetector do
  describe ".detect" do
    context "with non-string values" do
      it "returns empty array for nil" do
        expect(described_class.detect(nil)).to eq([])
      end

      it "returns empty array for integers" do
        expect(described_class.detect(42)).to eq([])
      end

      it "returns empty array for arrays" do
        expect(described_class.detect([1, 2, 3])).to eq([])
      end

      it "returns empty array for hashes" do
        expect(described_class.detect({ key: "value" })).to eq([])
      end

      it "returns empty array for symbols" do
        expect(described_class.detect(:symbol)).to eq([])
      end
    end

    context "with shell metacharacters" do
      it "detects semicolon" do
        errors = described_class.detect("hello; world")
        expect(errors).to include("contains dangerous shell metacharacter: ;")
      end

      it "detects pipe" do
        errors = described_class.detect("cat file | less")
        expect(errors).to include("contains dangerous shell metacharacter: |")
      end

      it "detects ampersand" do
        errors = described_class.detect("sleep 100 &")
        expect(errors).to include("contains dangerous shell metacharacter: &")
      end

      it "detects dollar sign" do
        errors = described_class.detect("echo $PATH")
        expect(errors).to include("contains dangerous shell metacharacter: $")
      end

      it "detects backtick" do
        errors = described_class.detect("echo `whoami`")
        expect(errors).to include("contains dangerous shell metacharacter: `")
      end

      it "detects backslash" do
        errors = described_class.detect("path\\to\\file")
        expect(errors).to include("contains dangerous shell metacharacter: \\")
      end

      it "detects less than" do
        errors = described_class.detect("file < input")
        expect(errors).to include("contains dangerous shell metacharacter: <")
      end

      it "detects greater than" do
        errors = described_class.detect("file > output")
        expect(errors).to include("contains dangerous shell metacharacter: >")
      end

      it "detects opening parenthesis" do
        errors = described_class.detect("cmd (arg)")
        expect(errors).to include("contains dangerous shell metacharacter: (")
      end

      it "detects closing parenthesis" do
        errors = described_class.detect("cmd arg)")
        expect(errors).to include("contains dangerous shell metacharacter: )")
      end

      it "detects multiple metacharacters" do
        errors = described_class.detect("; | & $ `")
        expect(errors.length).to be > 1
      end

      it "limits errors to MAX_ERRORS (3)" do
        errors = described_class.detect("; | & $ ` \\ < > ( )")
        expect(errors.length).to be <= 3
      end

      it "allows clean strings" do
        errors = described_class.detect("hello world 123")
        expect(errors).to be_empty
      end
    end

    context "with SQL injection patterns" do
      it "detects OR 1=1" do
        errors = described_class.detect("' OR 1=1--")
        expect(errors).to include("contains potential SQL injection pattern")
      end

      it "detects OR with string comparison" do
        errors = described_class.detect("' OR 'x'='x")
        expect(errors).to include("contains potential SQL injection pattern")
      end

      it "detects UNION SELECT" do
        errors = described_class.detect("1 UNION SELECT * FROM users")
        expect(errors).to include("contains potential SQL injection pattern")
      end

      it "detects DROP TABLE" do
        errors = described_class.detect("; DROP TABLE users")
        expect(errors).to include("contains potential SQL injection pattern")
      end

      it "detects SQL comment" do
        errors = described_class.detect("admin'--")
        expect(errors).to include("contains potential SQL injection pattern")
      end

      it "is case insensitive" do
        errors = described_class.detect("union select")
        expect(errors).to include("contains potential SQL injection pattern")
      end

      it "allows normal SQL" do
        errors = described_class.detect("SELECT * FROM users WHERE id = 1")
        # Should not detect as SQL injection (no dangerous patterns)
        sql_errors = errors.select { |e| e.include?("SQL injection") }
        expect(sql_errors).to be_empty
      end
    end

    context "with path traversal patterns" do
      it "detects ../ unix style" do
        errors = described_class.detect("../etc/passwd")
        expect(errors).to include("contains path traversal attempt")
      end

      it "detects ..\\ windows style" do
        errors = described_class.detect("..\\windows\\system32")
        expect(errors).to include("contains path traversal attempt")
      end

      it "detects URL-encoded traversal" do
        errors = described_class.detect("%2e%2e/etc/passwd")
        expect(errors).to include("contains path traversal attempt")
      end

      it "detects double-encoded traversal" do
        errors = described_class.detect("%252e%252e")
        expect(errors).to include("contains path traversal attempt")
      end

      it "detects case-insensitive encoded traversal" do
        errors = described_class.detect("%2E%2E/file")
        expect(errors).to include("contains path traversal attempt")
      end

      it "allows normal paths" do
        errors = described_class.detect("/home/user/documents/file.txt")
        path_errors = errors.select { |e| e.include?("path traversal") }
        expect(path_errors).to be_empty
      end

      it "allows relative paths without traversal" do
        errors = described_class.detect("./documents/file.txt")
        path_errors = errors.select { |e| e.include?("path traversal") }
        expect(path_errors).to be_empty
      end
    end

    context "with multiple violation types" do
      it "detects both shell and SQL in one string" do
        errors = described_class.detect("; DROP TABLE users")
        expect(errors.size).to be >= 1
      end

      it "stops after MAX_ERRORS" do
        # Multiple shell metacharacters
        errors = described_class.detect("; | & $ `")
        expect(errors.length).to be <= 3
      end

      it "includes most critical errors first" do
        errors = described_class.detect("; | &")
        expect(errors.length).to be > 0
      end
    end

    context "with edge cases" do
      it "handles empty string" do
        expect(described_class.detect("")).to be_empty
      end

      it "handles string with only whitespace" do
        expect(described_class.detect("   \n\t  ")).to be_empty
      end

      it "detects dangerous char at start" do
        errors = described_class.detect(";cmd")
        expect(errors).to include("contains dangerous shell metacharacter: ;")
      end

      it "detects dangerous char at end" do
        errors = described_class.detect("cmd;")
        expect(errors).to include("contains dangerous shell metacharacter: ;")
      end

      it "detects repeated dangerous chars" do
        errors = described_class.detect(";;;;;;")
        expect(errors).to include("contains dangerous shell metacharacter: ;")
      end
    end
  end

  describe ".sanitize" do
    it "removes shell metacharacters" do
      result = described_class.sanitize("hello; world")
      expect(result).to eq("hello world")
    end

    it "removes pipe characters" do
      result = described_class.sanitize("cat file | less")
      expect(result).to eq("cat file  less")
    end

    it "removes ampersand" do
      result = described_class.sanitize("sleep &")
      expect(result).to eq("sleep ")
    end

    it "removes dollar signs" do
      result = described_class.sanitize("echo $PATH")
      expect(result).to eq("echo PATH")
    end

    it "removes backticks" do
      result = described_class.sanitize("echo `whoami`")
      expect(result).to eq("echo whoami")
    end

    it "removes backslashes" do
      result = described_class.sanitize("path\\to\\file")
      expect(result).to eq("pathtofile")
    end

    it "removes angle brackets" do
      result = described_class.sanitize("file < input > output")
      expect(result).to eq("file  input  output")
    end

    it "removes parentheses" do
      result = described_class.sanitize("cmd (arg)")
      expect(result).to eq("cmd arg")
    end

    it "returns non-string unchanged" do
      expect(described_class.sanitize(42)).to eq(42)
      expect(described_class.sanitize(nil)).to be_nil
      expect(described_class.sanitize([])).to eq([])
    end

    it "handles string with no dangerous chars" do
      result = described_class.sanitize("hello world 123")
      expect(result).to eq("hello world 123")
    end

    it "removes multiple occurrences of same char" do
      result = described_class.sanitize(";;command;;")
      expect(result).to eq("command")
    end

    it "removes all defined shell metacharacters" do
      all_chars = "; | & $ ` \\ < > ( )"
      result = described_class.sanitize(all_chars)
      # After removing all metacharacters and extra spaces
      expect(result).not_to include(";")
      expect(result).not_to include("|")
      expect(result).not_to include("&")
    end

    it "preserves spacing structure" do
      result = described_class.sanitize("hello ; world ; test")
      # Spaces should remain around removed semicolons
      expect(result).to include("hello")
      expect(result).to include("world")
      expect(result).to include("test")
    end
  end

  describe "constants" do
    it "has SHELL_METACHARACTERS constant" do
      expect(described_class::SHELL_METACHARACTERS).to be_an(Array)
      expect(described_class::SHELL_METACHARACTERS).to include(";", "|", "&", "$", "`", "\\", "<", ">", "(", ")")
    end

    it "has MAX_ERRORS constant" do
      expect(described_class::MAX_ERRORS).to eq(3)
    end

    it "has SQL_PATTERNS constant" do
      expect(described_class::SQL_PATTERNS).to be_an(Array)
      expect(described_class::SQL_PATTERNS).to all(be_a(Regexp))
    end

    it "has PATH_TRAVERSAL_PATTERNS constant" do
      expect(described_class::PATH_TRAVERSAL_PATTERNS).to be_an(Array)
      expect(described_class::PATH_TRAVERSAL_PATTERNS).to all(be_a(Regexp))
    end
  end
end
