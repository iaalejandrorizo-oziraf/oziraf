import { PaginationQueryDto } from '../dto/pagination-query.dto';

export function getPagination(options: PaginationQueryDto = {}) {
  const page = Math.max(options.page ?? 1, 1);
  const limit = Math.min(Math.max(options.limit ?? 20, 1), 50);

  return {
    skip: (page - 1) * limit,
    take: limit,
  };
}
