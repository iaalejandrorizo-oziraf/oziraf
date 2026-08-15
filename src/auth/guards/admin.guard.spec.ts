import { ExecutionContext, ForbiddenException } from '@nestjs/common';
import { AdminGuard } from './admin.guard';

describe('AdminGuard', () => {
  let guard: AdminGuard;

  const createContext = (role?: string) =>
    ({
      switchToHttp: () => ({
        getRequest: () => ({
          user: {
            role,
          },
        }),
      }),
    }) as ExecutionContext;

  beforeEach(() => {
    guard = new AdminGuard();
  });

  it('allows admin users', () => {
    expect(guard.canActivate(createContext('ADMIN'))).toBe(true);
  });

  it('rejects non-admin users', () => {
    expect(() => guard.canActivate(createContext('USER'))).toThrow(
      ForbiddenException,
    );
  });
});
