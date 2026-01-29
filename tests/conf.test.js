// Imports 
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
const getArg = (name) => {
  const arg = args.find(arg => arg.startsWith(`--${name}=`));
  return arg ? arg.split('=')[1] : null;
};

const URL = getArg('url');
const VERSION = getArg('version');

if (!URL) {
  throw new Error('Missing required --url= argument');
}
if (!VERSION) {
  throw new Error('Missing required --version= argument');
}

console.log(`Testing URL: ${URL}`);
console.log(`Testing VERSION: ${VERSION}`);

describe('abcdesktop services tests', function(){
  var driver;
  
  beforeAll(async function(){
    // create Chrome driver with specified options 
    driver =  await new webdriver.Builder().forBrowser(webdriver.Browser.CHROME).setChromeOptions(options).build();

    // set up size of the driver window
    await driver.manage().window().setRect({ width: 1400, height: 768 });
  }, 30000);

  afterAll(async function(){
    await driver.quit();
  });

    it("connect to abcdesktop", function(){
      driver.get(`${URL}`);
    })

    it("the login page should be visible", async function(){
      // get login screen element 
      let loginScreen = await driver.findElement(webdriver.By.id("loginScreen"));

      // wait for the page tu fully loaded
      await driver.wait(webdriver.until.elementIsVisible(loginScreen), 300000);

      // check that login screen is not hidden
      await loginScreen.getAttribute("class").then(function(className){
        expect(className.includes("hide")).toBe(false);
      });
      
      
      let encodedString = await driver.takeScreenshot();
      await fs.writeFile('./screens/login-page.png', encodedString, 'base64');
    }, 300000)

    it('click on connect with empty user field, should display "user can not be an empty string', async function(){
      // get password field, connect button and connection status text element
      let pwd = await driver.findElement(webdriver.By.id("ADpassword"));
      let connect_button = await driver.findElement(webdriver.By.id("connectAD"));
      let status_text = await driver.findElement(webdriver.By.id("statusText"));

      // try to login with only a password
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
      // get username field, connect button and connection status text element
      let login = await driver.findElement(webdriver.By.id("cuid"));
      let connect_button = await driver.findElement(webdriver.By.id("connectAD"));
      let status_text = await driver.findElement(webdriver.By.id("statusText"));

      // try to login with only a username
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

      // get username field, password field, connect button and connection status text element
      let login = await driver.findElement(webdriver.By.id("cuid"));
      let pwd = await driver.findElement(webdriver.By.id("ADpassword"));
      let connect_button = await driver.findElement(webdriver.By.id("connectAD"));
      let status_text = await driver.findElement(webdriver.By.id("statusText"));

      // try to login with bad creditentials
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

      // get username field, password field, connect button and connection status text element
      let login = await driver.findElement(webdriver.By.id("cuid"));
      let pwd = await driver.findElement(webdriver.By.id("ADpassword"));
      let connect_button = await driver.findElement(webdriver.By.id("connectAD"));
      let loginScreen = await driver.findElement(webdriver.By.id("loginScreen"));

      // login with fry account
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

    it("open menu", async function(){
      let notification1 = await driver.findElement(webdriver.By.id("notification1"));
      await driver.wait(webdriver.until.elementIsNotVisible(notification1), 300000);
      
      // get the menu button and the menu itself
      let menu_button = await driver.findElement(webdriver.By.id("name"));
      let menu = await driver.findElement(webdriver.By.id("mainmenu")); 

      // wait for the menu to be open before taking screenshot
      await menu_button.click();
      await driver.wait(webdriver.until.elementIsVisible(menu), 300000);
      let encodedString = await driver.takeScreenshot();
      await fs.writeFile('./screens/fry-desktop-menu-open.png', encodedString, 'base64');
    }, 300000)

    it("open application menu", async function(){
      // get aplications button element
      let application_menu_button = await driver.findElement(webdriver.By.id("applications-name"));
      await application_menu_button.click();

      // wait for the application menu to be dynamicaly created
      await new Promise((r) => setTimeout(r, 1000));
      let encodedString = await driver.takeScreenshot();
      await fs.writeFile('./screens/fry-desktop-application-menu-open.png', encodedString, 'base64');
    }, 300000)

    it("start firefox", async function(){
      // get firefox icon element
      let firefox = await driver.findElement(webdriver.By.id(`ghcr.io/abcdesktopio/firefox.d:${VERSION}`)); 
      await firefox.click();

      let applicationstatus = await driver.findElement(webdriver.By.id("applicationstatus"));
      await driver.wait(webdriver.until.elementIsVisible(applicationstatus), 3000);
      let encodedString = await driver.takeScreenshot();
      await fs.writeFile('./screens/fry-desktop-firefox-houglass-visible.png', encodedString, 'base64');
    }, 300000)

    it("open menu", async function(){
      // get the menu button and the menu itself
      let menu_button = await driver.findElement(webdriver.By.id("name"));
      let menu = await driver.findElement(webdriver.By.id("mainmenu")); 

      // wait for the menu to be open before taking screenshot
      await menu_button.click();
      await driver.wait(webdriver.until.elementIsVisible(menu), 300000);
      let encodedString = await driver.takeScreenshot();
      await fs.writeFile('./screens/fry-desktop-menu-open.png', encodedString, 'base64');
    }, 300000)

    it("open log-out modal", async function(){
      // get logout modal element
      let logout_modal_button = await driver.findElement(webdriver.By.id("log-out-name"));
      await logout_modal_button.click();

      // wait for the logoff button to be dynamicaly created
      await new Promise((r) => setTimeout(r, 1000));
      let logoff_button = await driver.findElement(webdriver.By.className("btn button-log-off")); 

      //wait for the logoff modal to be visible before taking screenshot
      await driver.wait(webdriver.until.elementIsVisible(logoff_button), 300000);
      let encodedString = await driver.takeScreenshot();
      await fs.writeFile('./screens/fry-desktop-logout-modal-open.png', encodedString, 'base64');
    }, 300000)

    it("perform logoff", async function(){
      // get logoff button 
      let logoff_button = await driver.findElement(webdriver.By.className("btn button-log-off")); 

      // disconnect from the session and take a screenshot
      await logoff_button.click();
      await driver.navigate().refresh();
      let encodedString = await driver.takeScreenshot();
      await fs.writeFile('./screens/login-page-after-logoff.png', encodedString, 'base64');
    }, 300000)

});  
