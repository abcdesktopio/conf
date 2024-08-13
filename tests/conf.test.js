// Imports 
const { exec } = require("child_process");
const util = require('util');
const execPromise = util.promisify(exec);
const fs = require('fs').promises;
const webdriver = require('selenium-webdriver');
const Chrome = require('selenium-webdriver/chrome');
// Chrome driver options
const options = new Chrome.Options();
options.addArguments("--headless");
options.addArguments('--no-sandbox');
options.setBinaryPath('/opt/google/chrome/google-chrome');

// parsing command line arguments to retrieve the URL to test
const args = process.argv.slice(2);
const urlArg = args.find(arg => arg.startsWith('--url='));
const URL = urlArg ? urlArg.split('=')[1] : null;

describe('abcdesktop services tests', function(){
  var driver;
  
  beforeAll(async function(){
    driver =  await new webdriver.Builder().forBrowser(webdriver.Browser.CHROME).setChromeOptions(options).build();
    await driver.manage().window().setRect({ width: 1400, height: 768 });
  }, 30000);

  afterAll(async function(){
    await driver.quit();
  });

    it("connect to abcdesktop", function(){
      driver.get(`${URL}`);
    })

    it("the login page should be visible", async function(){
      let loginScreen = await driver.findElement(webdriver.By.id("loginScreen"));
      await loginScreen.getAttribute("class").then(function(className){
        expect(className.includes("hide")).toBe(false);
      });
      let encodedString = await driver.takeScreenshot();
      await fs.writeFile('./screens/login-page.png', encodedString, 'base64');
    })

    it('click on connect with empty user field, should display "user can not be an empty string', async function(){
      let pwd = await driver.findElement(webdriver.By.id("ADpassword"));
      let connect_button = await driver.findElement(webdriver.By.id("connectAD"));
      let status_text = await driver.findElement(webdriver.By.id("statusText"));
      await pwd.sendKeys("toto");
      await connect_button.click();
      await new Promise((r) => setTimeout(r, 1000));
      await status_text.getText().then(function(text){
        expect(text).toBe("user can not be an empty string");
      });
      let encodedString = await driver.takeScreenshot();
      await fs.writeFile('./screens/login-page-no-user.png', encodedString, 'base64');
    })

    it('click on connect with empty password field, should display "password can not be an empty string', async function(){
      await driver.navigate().refresh();
      let login = await driver.findElement(webdriver.By.id("cuid"));
      let connect_button = await driver.findElement(webdriver.By.id("connectAD"));
      let status_text = await driver.findElement(webdriver.By.id("statusText"));
      await login.sendKeys("toto");
      await connect_button.click();
      await new Promise((r) => setTimeout(r, 1000));
      await status_text.getText().then(function(text){
        expect(text).toBe("password can not be an empty string");
      });
      let encodedString = await driver.takeScreenshot();
      await fs.writeFile('./screens/login-page-no-pwd.png', encodedString, 'base64');
    })

    it("try to login with bad creditentials", async function(){
      await driver.navigate().refresh();
      let login = await driver.findElement(webdriver.By.id("cuid"));
      let pwd = await driver.findElement(webdriver.By.id("ADpassword"));
      let connect_button = await driver.findElement(webdriver.By.id("connectAD"));
      let status_text = await driver.findElement(webdriver.By.id("statusText"));
      await login.sendKeys("toto");
      await pwd.sendKeys("toto");
      await connect_button.click();
      await new Promise((r) => setTimeout(r, 1000));
      await status_text.getText().then(function(text){
        expect(text).toBe("invalidCredentials");
      });
      let encodedString = await driver.takeScreenshot();
      await fs.writeFile('./screens/login-page-bad-creditentials.png', encodedString, 'base64');
    })

    it("login as fry", async function(){
      await driver.navigate().refresh();
      let login = await driver.findElement(webdriver.By.id("cuid"));
      let pwd = await driver.findElement(webdriver.By.id("ADpassword"));
      let connect_button = await driver.findElement(webdriver.By.id("connectAD"));
      let loginScreen = await driver.findElement(webdriver.By.id("loginScreen"));
      await login.sendKeys("Philip J. Fry");
      await pwd.sendKeys("fry");
      await connect_button.click();
      await driver.wait(webdriver.until.elementIsNotVisible(loginScreen), 300000);
      await loginScreen.getAttribute("class").then(function(className){
        expect(className.includes("hide")).toBe(true);
      });
      let encodedString = await driver.takeScreenshot();
      await fs.writeFile('./screens/fry-desktop.png', encodedString, 'base64');
    }, 300000)

    it("start firefox", async function(){
      let { stdout, stderr } = await execPromise(`kubectl get pods -l run=pyos-od -o jsonpath={.items..metadata.name} -n abcdesktop | awk '{print $1}'`);
      let pyos_pod = stdout;
      let currentState
      let firefox = await driver.findElement(webdriver.By.id("abcdesktopio/firefox.d:3.2"));
      await firefox.click();
      do {
        currentState = await firefox.getAttribute("class");
        console.debug(currentState);
        let { stdout, stderr } = await execPromise(`kubectl logs ${pyos_pod} -n abcdesktop | tail`);
        console.log(stdout);
      } while (currentState !== "active");
      await new Promise((r) => setTimeout(r, 5000));
      let encodedString = await driver.takeScreenshot();
      await fs.writeFile('./screens/fry-desktop-firefox-running.png', encodedString, 'base64');
    }, 300000)

    it("open menu", async function(){
      let menu_button = await driver.findElement(webdriver.By.id("name"));
      let menu = await driver.findElement(webdriver.By.id("mainmenu")); 
      await menu_button.click();
      await driver.wait(webdriver.until.elementIsVisible(menu), 300000);
      let encodedString = await driver.takeScreenshot();
      await fs.writeFile('./screens/fry-desktop-menu-open.png', encodedString, 'base64');
    }, 300000)

    it("open log-out modal", async function(){
      let logout_modal_button = await driver.findElement(webdriver.By.id("log-out-name"));
      await logout_modal_button.click();
      await new Promise((r) => setTimeout(r, 1000));
      let logoff_button = await driver.findElement(webdriver.By.className("btn button-log-off")); 
      await driver.wait(webdriver.until.elementIsVisible(logoff_button), 300000);
      let encodedString = await driver.takeScreenshot();
      await fs.writeFile('./screens/fry-desktop-logout-modal-open.png', encodedString, 'base64');
    }, 300000)

    it("perform logoff", async function(){
      let logoff_button = await driver.findElement(webdriver.By.className("btn button-log-off")); 
      await logoff_button.click();
      await driver.navigate().refresh();
      let encodedString = await driver.takeScreenshot();
      await fs.writeFile('./screens/login-page-after-logoff.png', encodedString, 'base64');
    }, 300000)

});  