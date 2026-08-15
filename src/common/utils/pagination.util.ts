import { PaginationQueryDto } from '../dto/pagination-query.dto';

export function getPaginationParams(options: PaginationQueryDto = {}) {
  const page = Math.max(options.page ?? 1, 1);
  const limit = Math.min(Math.max(options.limit ?? 20, 1), 50);

  return {
    page,
    limit,
    skip: (page - 1) * limit,
    take: limit,
  };
}

export function getPagination(options: PaginationQueryDto = {}) {
  const { skip, take } = getPaginationParams(options);

  return {
    skip,
    take,
  };
}

export function buildPaginatedResponse<T>(
  data: T[],
  total: number,
  options: PaginationQueryDto = {},
) {
  const { page, limit } = getPaginationParams(options);

  return {
    data,
    page,
    limit,
    total,
    totalPages: Math.ceil(total / limit),
  };
}
