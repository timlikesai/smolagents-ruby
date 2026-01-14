require "webmock/rspec"

# Only define Selenium-related tests if selenium-webdriver is available
begin
  require "selenium-webdriver"
  SELENIUM_AVAILABLE = true
rescue LoadError
  SELENIUM_AVAILABLE = false
end

RSpec.describe Smolagents::Concerns::Browser do
  let(:test_class) do
    Class.new do
      include Smolagents::Concerns::Browser
    end
  end

  let(:browser_instance) { test_class.new }

  before do
    # Clear driver state before each test
    described_class.driver = nil
  end

  after do
    # Clean up driver state after each test
    described_class.driver&.quit
    described_class.driver = nil
  end

  describe "INSTRUCTIONS constant" do
    it "contains instructions for agents" do
      expect(described_class::INSTRUCTIONS).to include("web browser")
      expect(described_class::INSTRUCTIONS).to include("browser_go_to")
      expect(described_class::INSTRUCTIONS).to include("browser_click")
      expect(described_class::INSTRUCTIONS).to include("screenshot")
    end

    it "is frozen" do
      expect(described_class::INSTRUCTIONS).to be_frozen
    end

    it "mentions dismissing popups and modals" do
      expect(described_class::INSTRUCTIONS).to include("modals")
      expect(described_class::INSTRUCTIONS).to include("cookie banners")
    end

    it "advises against login attempts" do
      expect(described_class::INSTRUCTIONS).to include("Never try to login")
    end
  end

  describe ".start" do
    it "creates a Chrome WebDriver instance with default options" do
      skip unless SELENIUM_AVAILABLE

      driver = described_class.start
      expect(driver).to be_a(Selenium::WebDriver)
      expect(described_class.driver).to eq(driver)

      driver.quit
      described_class.driver = nil
    end

    it "accepts headless parameter" do
      skip unless SELENIUM_AVAILABLE

      driver = described_class.start(headless: true)
      expect(driver).to be_a(Selenium::WebDriver)

      driver.quit
      described_class.driver = nil
    end

    it "accepts custom window_size" do
      skip unless SELENIUM_AVAILABLE

      driver = described_class.start(window_size: [1920, 1080])
      expect(driver).to be_a(Selenium::WebDriver)

      driver.quit
      described_class.driver = nil
    end

    it "sets default window size to [1000, 1350]" do
      skip unless SELENIUM_AVAILABLE

      driver = described_class.start
      expect(driver).to be_a(Selenium::WebDriver)

      driver.quit
      described_class.driver = nil
    end
  end

  describe ".stop" do
    it "quits the driver" do
      skip unless SELENIUM_AVAILABLE

      driver = described_class.start
      allow(driver).to receive(:quit)

      described_class.stop

      expect(driver).to have_received(:quit)
    end

    it "clears driver reference" do
      skip unless SELENIUM_AVAILABLE

      driver = described_class.start
      driver.quit

      described_class.stop
      expect(described_class.driver).to be_nil
    end

    it "is safe to call when driver not started" do
      expect { described_class.stop }.not_to raise_error
      expect(described_class.driver).to be_nil
    end

    it "is safe to call multiple times" do
      described_class.driver = nil
      expect { described_class.stop }.not_to raise_error
      expect { described_class.stop }.not_to raise_error
    end
  end

  describe ".driver=" do
    it "sets the driver instance" do
      skip unless SELENIUM_AVAILABLE
      mock_driver = instance_double(Selenium::WebDriver)
      described_class.driver = mock_driver

      expect(described_class.driver).to eq(mock_driver)
    end

    it "allows setting to nil" do
      skip unless SELENIUM_AVAILABLE
      mock_driver = instance_double(Selenium::WebDriver)
      described_class.driver = mock_driver
      described_class.driver = nil

      expect(described_class.driver).to be_nil
    end
  end

  describe ".screenshot" do
    it "returns nil when driver not started" do
      described_class.driver = nil
      expect(described_class.screenshot).to be_nil
    end

    it "returns an AgentImage when driver started" do
      skip unless SELENIUM_AVAILABLE

      mock_driver = instance_double(Selenium::WebDriver)
      png_bytes = "PNG_DATA".b
      allow(mock_driver).to receive(:screenshot_as).with(:png).and_return(png_bytes)

      described_class.driver = mock_driver
      image = described_class.screenshot

      expect(image).to be_a(Smolagents::AgentImage)
    end

    it "calls driver screenshot_as with png format" do
      skip unless SELENIUM_AVAILABLE
      mock_driver = instance_double(Selenium::WebDriver)
      allow(mock_driver).to receive(:screenshot_as).with(:png).and_return("PNG".b)

      described_class.driver = mock_driver
      described_class.screenshot

      expect(mock_driver).to have_received(:screenshot_as).with(:png)
    end

    it "wraps screenshot bytes in AgentImage" do
      skip unless SELENIUM_AVAILABLE
      mock_driver = instance_double(Selenium::WebDriver)
      png_bytes = "FAKE_PNG".b
      allow(mock_driver).to receive(:screenshot_as).with(:png).and_return(png_bytes)

      described_class.driver = mock_driver
      image = described_class.screenshot

      expect(image.data).to eq(png_bytes)
      expect(image.format).to eq("png")
    end
  end

  describe ".current_url" do
    it "returns nil when driver not started" do
      described_class.driver = nil
      expect(described_class.current_url).to be_nil
    end

    it "returns current URL from driver" do
      skip unless SELENIUM_AVAILABLE
      mock_driver = instance_double(Selenium::WebDriver)
      allow(mock_driver).to receive(:current_url).and_return("https://example.com/page")

      described_class.driver = mock_driver
      url = described_class.current_url

      expect(url).to eq("https://example.com/page")
    end

    it "calls driver current_url method" do
      skip unless SELENIUM_AVAILABLE
      mock_driver = instance_double(Selenium::WebDriver)
      allow(mock_driver).to receive(:current_url).and_return("https://test.com")

      described_class.driver = mock_driver
      described_class.current_url

      expect(mock_driver).to have_received(:current_url)
    end
  end

  describe ".wait_for_page_ready" do
    it "returns nil when driver not started" do
      described_class.driver = nil
      result = described_class.wait_for_page_ready

      expect(result).to be_nil
    end

    it "uses explicit wait with timeout" do
      skip unless SELENIUM_AVAILABLE

      mock_driver = instance_double(Selenium::WebDriver)
      mock_wait = instance_double(Selenium::WebDriver::Wait)

      allow(Selenium::WebDriver::Wait).to receive(:new)
        .with(timeout: 10, interval: 0.1)
        .and_return(mock_wait)
      allow(mock_wait).to receive(:until).and_return(true)
      allow(mock_driver).to receive(:execute_script).and_return("complete")

      described_class.driver = mock_driver
      described_class.wait_for_page_ready

      expect(Selenium::WebDriver::Wait).to have_received(:new).with(timeout: 10, interval: 0.1)
    end

    it "executes readyState check script" do
      skip unless SELENIUM_AVAILABLE
      mock_driver = instance_double(Selenium::WebDriver)
      mock_wait = instance_double(Selenium::WebDriver::Wait)

      allow(Selenium::WebDriver::Wait).to receive(:new).and_return(mock_wait)
      allow(mock_wait).to receive(:until) do |&block|
        block.call == "complete"
      end
      allow(mock_driver).to receive(:execute_script)
        .with("return document.readyState")
        .and_return("complete")

      described_class.driver = mock_driver
      described_class.wait_for_page_ready

      expect(mock_driver).to have_received(:execute_script).with("return document.readyState")
    end

    it "rescues TimeoutError and continues" do
      skip unless SELENIUM_AVAILABLE

      mock_driver = instance_double(Selenium::WebDriver)
      mock_wait = instance_double(Selenium::WebDriver::Wait)

      allow(Selenium::WebDriver::Wait).to receive(:new).and_return(mock_wait)
      allow(mock_wait).to receive(:until).and_raise(Selenium::WebDriver::Error::TimeoutError)

      described_class.driver = mock_driver

      expect { described_class.wait_for_page_ready }.not_to raise_error
    end

    it "accepts custom timeout parameter" do
      skip unless SELENIUM_AVAILABLE

      mock_driver = instance_double(Selenium::WebDriver)
      mock_wait = instance_double(Selenium::WebDriver::Wait)

      allow(Selenium::WebDriver::Wait).to receive(:new)
        .with(timeout: 5, interval: 0.1)
        .and_return(mock_wait)
      allow(mock_wait).to receive(:until).and_return(true)
      allow(mock_driver).to receive(:execute_script).and_return("complete")

      described_class.driver = mock_driver
      described_class.wait_for_page_ready(timeout: 5)

      expect(Selenium::WebDriver::Wait).to have_received(:new).with(timeout: 5, interval: 0.1)
    end
  end

  describe ".escape_xpath_string" do
    it "wraps simple strings without quotes in single quotes" do
      result = described_class.escape_xpath_string("simple")
      expect(result).to eq("'simple'")
    end

    it "wraps strings without quotes in single quotes" do
      result = described_class.escape_xpath_string("no quotes here")
      expect(result).to eq("'no quotes here'")
    end

    it "wraps strings with single quotes in double quotes" do
      result = described_class.escape_xpath_string("O'Brien")
      expect(result).to eq("\"O'Brien\"")
    end

    it "wraps strings with double quotes in single quotes" do
      result = described_class.escape_xpath_string('He said "hello"')
      expect(result).to eq("'He said \"hello\"'")
    end

    it "uses concat() for strings with both quote types" do
      result = described_class.escape_xpath_string("It's \"quoted\"")
      expect(result).to include("concat(")
      expect(result).to include("\"'\"")
    end

    it "splits on single quotes when both quote types present" do
      result = described_class.escape_xpath_string("O'Brien's \"book\"")
      parts = result.split(", ")
      expect(parts.length).to be > 1
    end

    it "handles empty string" do
      result = described_class.escape_xpath_string("")
      expect(result).to eq("''")
    end

    it "handles string with only single quote" do
      result = described_class.escape_xpath_string("'")
      expect(result).to eq("\"'\"")
    end

    it "handles string with only double quote" do
      result = described_class.escape_xpath_string('"')
      expect(result).to eq("'\"'")
    end

    it "handles multiple single quotes" do
      result = described_class.escape_xpath_string("it's what's")
      expect(result).to start_with("\"")
      expect(result).to end_with("\"")
    end

    it "handles multiple double quotes" do
      result = described_class.escape_xpath_string('say "this" and "that"')
      expect(result).to start_with("'")
      expect(result).to end_with("'")
    end

    it "produces valid XPath concat syntax with mixed quotes" do
      result = described_class.escape_xpath_string("can't \"do\" it")
      expect(result).to match(/^concat\(/)
      expect(result).to match(/\)$/)
      expect(result).to include("\"'\"")
    end
  end

  describe ".save_screenshot_callback" do
    it "returns a Proc" do
      callback = described_class.save_screenshot_callback
      expect(callback).to be_a(Proc)
    end

    it "does nothing when driver not started" do
      described_class.driver = nil
      callback = described_class.save_screenshot_callback

      mock_step = double("step")
      allow(mock_step).to receive(:observations_images=)
      allow(mock_step).to receive(:observations=)

      callback.call(mock_step, nil)

      expect(mock_step).not_to have_received(:observations_images=)
      expect(mock_step).not_to have_received(:observations=)
    end

    it "updates step with screenshot" do
      skip unless SELENIUM_AVAILABLE

      mock_driver = instance_double(Selenium::WebDriver)
      mock_wait = instance_double(Selenium::WebDriver::Wait)
      png_bytes = "FAKE_PNG".b

      allow(Selenium::WebDriver::Wait).to receive(:new).and_return(mock_wait)
      allow(mock_wait).to receive(:until).and_return(true)
      allow(mock_driver).to receive(:screenshot_as).with(:png).and_return(png_bytes)
      allow(mock_driver).to receive_messages(execute_script: "complete", current_url: "https://example.com")

      described_class.driver = mock_driver

      mock_step = instance_double(Step)
      allow(mock_step).to receive(:observations=)
      allow(mock_step).to receive(:observations).and_return(nil)

      callback = described_class.save_screenshot_callback
      callback.call(mock_step, nil)

      expect(mock_step).to have_received(:observations_images=)
    end

    it "updates step with current URL" do
      skip unless SELENIUM_AVAILABLE

      mock_driver = instance_double(Selenium::WebDriver)
      mock_wait = instance_double(Selenium::WebDriver::Wait)
      png_bytes = "FAKE_PNG".b

      allow(Selenium::WebDriver::Wait).to receive(:new).and_return(mock_wait)
      allow(mock_wait).to receive(:until).and_return(true)
      allow(mock_driver).to receive(:screenshot_as).with(:png).and_return(png_bytes)
      allow(mock_driver).to receive_messages(execute_script: "complete", current_url: "https://example.com/page")

      described_class.driver = mock_driver

      mock_step = instance_double(Step)
      allow(mock_step).to receive(:observations_images=)
      allow(mock_step).to receive(:observations=)
      allow(mock_step).to receive(:observations).and_return(nil)

      callback = described_class.save_screenshot_callback
      callback.call(mock_step, nil)

      expect(mock_step).to have_received(:observations=).with(%r{Current url: https://example.com/page})
    end

    it "appends URL info to existing observations" do
      skip unless SELENIUM_AVAILABLE

      mock_driver = instance_double(Selenium::WebDriver)
      mock_wait = instance_double(Selenium::WebDriver::Wait)
      png_bytes = "FAKE_PNG".b

      allow(Selenium::WebDriver::Wait).to receive(:new).and_return(mock_wait)
      allow(mock_wait).to receive(:until).and_return(true)
      allow(mock_driver).to receive(:screenshot_as).with(:png).and_return(png_bytes)
      allow(mock_driver).to receive_messages(execute_script: "complete", current_url: "https://example.com")

      described_class.driver = mock_driver

      mock_step = instance_double(Step)
      allow(mock_step).to receive(:observations_images=)
      allow(mock_step).to receive(:observations).and_return("Previous observation")
      allow(mock_step).to receive(:observations=)

      callback = described_class.save_screenshot_callback
      callback.call(mock_step, nil)

      expect(mock_step).to have_received(:observations=) do |value|
        expect(value).to include("Previous observation")
        expect(value).to include("Current url")
      end
    end

    it "calls wait_for_page_ready before screenshot" do
      skip unless SELENIUM_AVAILABLE

      mock_driver = instance_double(Selenium::WebDriver)
      mock_wait = instance_double(Selenium::WebDriver::Wait)

      allow(Selenium::WebDriver::Wait).to receive(:new).and_return(mock_wait)
      allow(mock_wait).to receive(:until).and_return(true)
      allow(mock_driver).to receive(:screenshot_as).with(:png).and_return("PNG".b)
      allow(mock_driver).to receive_messages(execute_script: "complete", current_url: "https://example.com")

      described_class.driver = mock_driver

      allow(described_class).to receive(:wait_for_page_ready).and_call_original

      mock_step = instance_double(Step)
      allow(mock_step).to receive(:observations_images=)
      allow(mock_step).to receive(:observations=)
      allow(mock_step).to receive(:observations).and_return(nil)

      callback = described_class.save_screenshot_callback
      callback.call(mock_step, nil)

      expect(described_class).to have_received(:wait_for_page_ready)
    end
  end

  describe "#browser_driver" do
    it "returns the class driver" do
      skip unless SELENIUM_AVAILABLE
      mock_driver = instance_double(Selenium::WebDriver)
      described_class.driver = mock_driver

      result = browser_instance.browser_driver
      expect(result).to eq(mock_driver)
    end

    it "returns nil when driver not started" do
      described_class.driver = nil
      result = browser_instance.browser_driver

      expect(result).to be_nil
    end
  end

  describe "#require_browser!" do
    it "does nothing when browser initialized" do
      skip unless SELENIUM_AVAILABLE
      mock_driver = instance_double(Selenium::WebDriver)
      described_class.driver = mock_driver

      expect { browser_instance.require_browser! }.not_to raise_error
    end

    it "raises RuntimeError when browser not initialized" do
      described_class.driver = nil

      expect { browser_instance.require_browser! }
        .to raise_error(RuntimeError, /Browser not initialized/)
    end
  end

  describe "#escape_xpath_string" do
    it "delegates to class method" do
      allow(described_class).to receive(:escape_xpath_string).with("test").and_return("'test'")

      result = browser_instance.escape_xpath_string("test")

      expect(result).to eq("'test'")
      expect(described_class).to have_received(:escape_xpath_string).with("test")
    end

    it "returns properly escaped XPath string" do
      result = browser_instance.escape_xpath_string("O'Brien")
      expect(result).to eq("\"O'Brien\"")
    end

    it "handles mixed quotes via delegation" do
      result = browser_instance.escape_xpath_string("can't \"do\"")
      expect(result).to include("concat(")
    end
  end
end
