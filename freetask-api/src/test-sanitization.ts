import { SanitizeInputInterceptor } from './common/interceptors/sanitize-input.interceptor';
import { ExecutionContext, CallHandler } from '@nestjs/common';
import { of } from 'rxjs';

class MockExecutionContext {
    private req: any;
    constructor(req: any) {
        this.req = req;
    }
    switchToHttp() {
        return {
            getRequest: () => this.req,
        };
    }
}

class MockCallHandler {
    handle() {
        return of('next');
    }
}

async function runTest() {
    const interceptor = new SanitizeInputInterceptor();

    const mockReq = {
        body: {
            password: '<script>alert("hacked")</script>',
            token: 'javascript:alert(1)',
            title: 'A/B Test for C++ and UI/UX',
            nested: {
                description: '<img src=x onerror=alert(1)> description here',
                arrayField: [
                    '<svg onload=alert(1)>',
                    'Clean string'
                ]
            }
        }
    };

    const context = new MockExecutionContext(mockReq) as unknown as ExecutionContext;
    const next = new MockCallHandler() as unknown as CallHandler;

    console.log('--- ORIGINAL REQUEST BODY ---');
    console.dir(mockReq.body, { depth: null });

    interceptor.intercept(context, next);

    console.log('\n--- SANITIZED REQUEST BODY ---');
    console.dir(mockReq.body, { depth: null });

    const body = mockReq.body;

    // Validation
    let passed = true;
    if (body.password !== '<script>alert("hacked")</script>') {
        console.error('FAIL: Password field was modified!');
        passed = false;
    }
    if (body.token !== 'javascript:alert(1)') {
        console.error('FAIL: token field was modified!');
        passed = false;
    }
    if (body.title !== 'A/B Test for C++ and UI/UX') {
        console.error('FAIL: Valid symbols in title were modified!');
        passed = false;
    }
    if (body.nested.description.includes('<img')) {
        console.error('FAIL: <img> tag was not stripped!');
        passed = false;
    }
    if (body.nested.arrayField[0].includes('<svg')) {
        console.error('FAIL: <svg> tag in array was not stripped!');
        passed = false;
    }

    if (passed) {
        console.log('\n✅ All tests passed successfully.');
    } else {
        console.error('\n❌ Tests failed.');
        process.exit(1);
    }
}

runTest();
